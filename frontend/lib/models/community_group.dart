import 'content_status.dart';

/// A COMMUNITY GROUP.
///
/// An age grade, a cultural group, an association, a union. One model rather
/// than one per kind, because what they need is the same: a roster, a way to
/// join, officers, dues, and somewhere to raise a problem. Splitting them into
/// separate types is how those things drift apart.
class CommunityGroup {
  const CommunityGroup({
    required this.id,
    required this.slug,
    required this.kind,
    required this.title,
    required this.status,
    this.kindLabel = 'Group',
    this.subtitle,
    this.motto,
    this.excerpt,
    this.body,
    this.formedYear,
    this.birthYearFrom,
    this.birthYearTo,
    this.joinPolicy = 'by_request',
    this.memberCount = 0,
    this.duesAmount,
    this.duesCurrency = 'NGN',
    this.duesPeriod,
    this.duesNotes,
    this.verificationStatus,
    this.membershipState,
    this.reason,
    this.officers = const <GroupOfficer>[],
    this.roster = const <GroupRosterEntry>[],
    this.paymentAccounts = const <GroupPaymentAccount>[],
    this.viewer = const GroupViewer(),
  });

  factory CommunityGroup.fromJson(Map<String, dynamic> json) {
    return CommunityGroup(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      kind: Json.str(json, 'kind', fallback: 'other'),
      kindLabel: Json.str(json, 'kind_label', fallback: 'Group'),
      title: Json.str(json, 'title', fallback: 'Group'),
      status: Json.str(json, 'status', fallback: 'draft'),
      subtitle: Json.strOrNull(json, 'subtitle'),
      motto: Json.strOrNull(json, 'motto'),
      excerpt: Json.strOrNull(json, 'excerpt'),
      body: Json.strOrNull(json, 'body'),
      formedYear: Json.intOrNull(json, 'formed_year'),
      birthYearFrom: Json.intOrNull(json, 'birth_year_from'),
      birthYearTo: Json.intOrNull(json, 'birth_year_to'),
      joinPolicy: Json.str(json, 'join_policy', fallback: 'by_request'),
      memberCount: Json.intVal(json, 'member_count'),
      duesAmount: Json.doubleOrNull(json, 'dues_amount'),
      duesCurrency: Json.str(json, 'dues_currency', fallback: 'NGN'),
      duesPeriod: Json.strOrNull(json, 'dues_period'),
      duesNotes: Json.strOrNull(json, 'dues_notes'),
      verificationStatus: Json.strOrNull(json, 'verification_status'),
      membershipState: Json.strOrNull(json, 'membership_state'),
      reason: Json.strOrNull(json, 'reason'),
      officers: Json.objectList(json, 'officers')
          .map(GroupOfficer.fromJson)
          .toList(growable: false),
      roster: Json.objectList(json, 'roster')
          .map(GroupRosterEntry.fromJson)
          .toList(growable: false),
      paymentAccounts: Json.objectList(json, 'payment_accounts')
          .map(GroupPaymentAccount.fromJson)
          .toList(growable: false),
      viewer: GroupViewer.fromJson(
        (json['viewer'] as Map<String, dynamic>?) ?? const <String, dynamic>{},
      ),
    );
  }

  final String id;
  final String slug;
  final String kind;
  final String kindLabel;
  final String title;
  final String status;
  final String? subtitle;
  final String? motto;
  final String? excerpt;
  final String? body;
  final int? formedYear;

  /// The years of birth an age grade covers. What makes "which grade is mine?"
  /// answerable at all — a grade without them cannot be matched to anybody.
  final int? birthYearFrom;
  final int? birthYearTo;

  final String joinPolicy;
  final int memberCount;
  final double? duesAmount;
  final String duesCurrency;
  final String? duesPeriod;
  final String? duesNotes;
  final String? verificationStatus;

  /// Where the viewer stands, on a list response.
  final String? membershipState;

  /// Why this group is being suggested. Set only on dashboard suggestions — a
  /// suggestion without a reason reads as an advertisement.
  final String? reason;

  final List<GroupOfficer> officers;
  final List<GroupRosterEntry> roster;
  final List<GroupPaymentAccount> paymentAccounts;
  final GroupViewer viewer;

  bool get isAgeGrade => kind == 'age_grade';
  bool get hasBracket => birthYearFrom != null && birthYearTo != null;

  /// "Born 1978–1987", the line that tells somebody whether a grade is theirs.
  String? get bracketLabel =>
      hasBracket ? 'Born $birthYearFrom–$birthYearTo' : null;

  bool get hasDues => duesAmount != null && duesAmount! > 0;
}

class GroupOfficer {
  const GroupOfficer({required this.userId, required this.name, required this.role, this.office});

  factory GroupOfficer.fromJson(Map<String, dynamic> json) => GroupOfficer(
        userId: Json.str(json, 'user_id'),
        name: Json.str(json, 'name', fallback: 'An officer'),
        role: Json.str(json, 'role', fallback: 'admin'),
        office: Json.strOrNull(json, 'office'),
      );

  final String userId;
  final String name;
  final String role;
  final String? office;

  String get roleLabel => switch (role) {
        'lead' => 'Lead',
        'treasurer' => 'Treasurer',
        _ => 'Officer',
      };
}

class GroupRosterEntry {
  const GroupRosterEntry({
    required this.id,
    required this.name,
    this.office,
    this.joinedYear,
    this.isDeceased = false,
  });

  factory GroupRosterEntry.fromJson(Map<String, dynamic> json) => GroupRosterEntry(
        id: Json.str(json, 'id'),
        name: Json.str(json, 'name', fallback: 'A member'),
        office: Json.strOrNull(json, 'office'),
        joinedYear: Json.intOrNull(json, 'joined_year'),
        isDeceased: Json.boolVal(json, 'is_deceased'),
      );

  final String id;
  final String name;
  final String? office;
  final int? joinedYear;
  final bool isDeceased;
}

/// Where a group's dues should be sent.
///
/// Never returned on a public route. A community's account number on an
/// indexable page is an invitation.
class GroupPaymentAccount {
  const GroupPaymentAccount({
    required this.id,
    required this.bankName,
    required this.accountName,
    required this.accountNumber,
    this.label,
    this.instructions,
    this.isPrimary = false,
  });

  factory GroupPaymentAccount.fromJson(Map<String, dynamic> json) => GroupPaymentAccount(
        id: Json.str(json, 'id'),
        bankName: Json.str(json, 'bank_name'),
        accountName: Json.str(json, 'account_name'),
        accountNumber: Json.str(json, 'account_number'),
        label: Json.strOrNull(json, 'label'),
        instructions: Json.strOrNull(json, 'instructions'),
        isPrimary: Json.boolVal(json, 'is_primary'),
      );

  final String id;
  final String bankName;
  final String accountName;
  final String accountNumber;
  final String? label;
  final String? instructions;
  final bool isPrimary;
}

/// Where the person reading the page stands in this group.
///
/// Sent by the server rather than worked out here, so the interface and the API
/// can never disagree about who may do what — the client draws what it is told
/// it may draw, and the server decides again on every request anyway.
class GroupViewer {
  const GroupViewer({
    this.isMember = false,
    this.isOfficer = false,
    this.officerRole,
    this.membershipState,
    this.canRequestToJoin = false,
  });

  factory GroupViewer.fromJson(Map<String, dynamic> json) => GroupViewer(
        isMember: Json.boolVal(json, 'is_member'),
        isOfficer: Json.boolVal(json, 'is_officer'),
        officerRole: Json.strOrNull(json, 'officer_role'),
        membershipState: Json.strOrNull(json, 'membership_state'),
        canRequestToJoin: Json.boolVal(json, 'can_request_to_join'),
      );

  final bool isMember;
  final bool isOfficer;
  final String? officerRole;
  final String? membershipState;
  final bool canRequestToJoin;

  bool get isTreasurer => officerRole == 'lead' || officerRole == 'treasurer';
  bool get isLead => officerRole == 'lead';
  bool get hasAsked => membershipState == 'requested';
}

/// A payment a member says they have made.
///
/// "Declared" and "confirmed" are different things and the interface must never
/// blur them: the platform never receives the money, so all it can honestly
/// show is what somebody said and whether the treasurer has agreed.
class DuesPayment {
  const DuesPayment({
    required this.id,
    required this.amount,
    required this.state,
    this.currency = 'NGN',
    this.payerName,
    this.periodLabel,
    this.paidOn,
    this.method,
    this.reference,
    this.note,
    this.officerNote,
  });

  factory DuesPayment.fromJson(Map<String, dynamic> json) => DuesPayment(
        id: Json.str(json, 'id'),
        amount: Json.doubleOrNull(json, 'amount') ?? 0,
        state: Json.str(json, 'state', fallback: 'declared'),
        currency: Json.str(json, 'currency', fallback: 'NGN'),
        payerName: Json.strOrNull(json, 'payer_name'),
        periodLabel: Json.strOrNull(json, 'period_label'),
        paidOn: Json.strOrNull(json, 'paid_on'),
        method: Json.strOrNull(json, 'method'),
        reference: Json.strOrNull(json, 'reference'),
        note: Json.strOrNull(json, 'note'),
        officerNote: Json.strOrNull(json, 'officer_note'),
      );

  final String id;
  final double amount;
  final String state;
  final String currency;
  final String? payerName;
  final String? periodLabel;
  final String? paidOn;
  final String? method;
  final String? reference;
  final String? note;
  final String? officerNote;

  String get stateLabel => switch (state) {
        'confirmed' => 'Confirmed',
        'disputed' => 'Queried',
        'cancelled' => 'Cancelled',
        _ => 'Awaiting confirmation',
      };
}

/// Something a member has raised with their group's officers.
class GroupIssue {
  const GroupIssue({
    required this.id,
    required this.subject,
    required this.kind,
    required this.state,
    this.detail,
    this.raisedByName,
    this.resolution,
    this.isPrivate = true,
    this.createdAt,
  });

  factory GroupIssue.fromJson(Map<String, dynamic> json) => GroupIssue(
        id: Json.str(json, 'id'),
        subject: Json.str(json, 'subject'),
        kind: Json.str(json, 'kind', fallback: 'other'),
        state: Json.str(json, 'state', fallback: 'open'),
        detail: Json.strOrNull(json, 'detail'),
        raisedByName: Json.strOrNull(json, 'raised_by_name'),
        resolution: Json.strOrNull(json, 'resolution'),
        isPrivate: Json.boolVal(json, 'is_private', fallback: true),
        createdAt: Json.strOrNull(json, 'created_at'),
      );

  final String id;
  final String subject;
  final String kind;
  final String state;
  final String? detail;
  final String? raisedByName;
  final String? resolution;
  final bool isPrivate;
  final String? createdAt;

  String get stateLabel => switch (state) {
        'acknowledged' => 'Seen by the officers',
        'resolved' => 'Resolved',
        'closed' => 'Closed',
        _ => 'Open',
      };
}

/// What a member's dashboard is told about groups.
class GroupSuggestions {
  const GroupSuggestions({
    this.suggested = const <CommunityGroup>[],
    this.mine = const <CommunityGroup>[],
    this.needsBirthDate = false,
    this.prompt,
  });

  factory GroupSuggestions.fromJson(Map<String, dynamic> json) => GroupSuggestions(
        suggested: Json.objectList(json, 'groups')
            .map(CommunityGroup.fromJson)
            .toList(growable: false),
        mine: Json.objectList(json, 'mine')
            .map(CommunityGroup.fromJson)
            .toList(growable: false),
        needsBirthDate: Json.boolVal(json, 'needsBirthDate'),
        prompt: Json.strOrNull(json, 'prompt'),
      );

  final List<CommunityGroup> suggested;
  final List<CommunityGroup> mine;

  /// Why nothing can be suggested. Shown instead of an empty box, because
  /// "we do not know when you were born" is actionable and silence is not.
  final bool needsBirthDate;
  final String? prompt;

  bool get isEmpty => suggested.isEmpty && mine.isEmpty && !needsBirthDate;
}
