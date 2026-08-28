import 'content_status.dart';

/// AN OPPORTUNITY.
///
/// A job, scholarship, grant, training place or apprenticeship.
///
/// The matching fields — `matchedSkills` against `totalSkills` — are the point
/// of the whole module, and `matchingActive` says whether those numbers mean
/// anything yet. A member with no skills recorded matches nothing everywhere,
/// and telling them why is the difference between a page that looks broken and
/// one they can act on.
class Opportunity {
  const Opportunity({
    required this.id,
    required this.slug,
    required this.kind,
    required this.title,
    required this.organisation,
    this.summary,
    this.description,
    this.requirements,
    this.benefits,
    this.locationTier = 'nigeria',
    this.locationText,
    this.isRemote = false,
    this.employmentType,
    this.payMin,
    this.payMax,
    this.payCurrency = 'NGN',
    this.payPeriod,
    this.payNote,
    this.applicationUrl,
    this.applicationEmail,
    this.applicationPhone,
    this.applicationNote,
    this.closesAt,
    this.posterName,
    this.verificationStatus = 'unverified',
    this.matchedSkills = 0,
    this.requiredSkills = 0,
    this.totalSkills = 0,
    this.matchingActive = false,
    this.isSaved = false,
    this.reportCount = 0,
    this.skills = const <OpportunitySkill>[],
    this.isOwner = false,
  });

  factory Opportunity.fromJson(Map<String, dynamic> json) => Opportunity(
        id: Json.str(json, 'id'),
        slug: Json.str(json, 'slug'),
        kind: Json.str(json, 'kind', fallback: 'job'),
        title: Json.str(json, 'title'),
        organisation: Json.str(json, 'organisation'),
        summary: Json.strOrNull(json, 'summary'),
        description: Json.strOrNull(json, 'description'),
        requirements: Json.strOrNull(json, 'requirements'),
        benefits: Json.strOrNull(json, 'benefits'),
        locationTier: Json.str(json, 'location_tier', fallback: 'nigeria'),
        locationText: Json.strOrNull(json, 'location_text'),
        isRemote: Json.boolVal(json, 'is_remote'),
        employmentType: Json.strOrNull(json, 'employment_type'),
        payMin: Json.doubleOrNull(json, 'pay_min'),
        payMax: Json.doubleOrNull(json, 'pay_max'),
        payCurrency: Json.str(json, 'pay_currency', fallback: 'NGN'),
        payPeriod: Json.strOrNull(json, 'pay_period'),
        payNote: Json.strOrNull(json, 'pay_note'),
        applicationUrl: Json.strOrNull(json, 'application_url'),
        applicationEmail: Json.strOrNull(json, 'application_email'),
        applicationPhone: Json.strOrNull(json, 'application_phone'),
        applicationNote: Json.strOrNull(json, 'application_note'),
        closesAt: Json.strOrNull(json, 'closes_at'),
        posterName: Json.strOrNull(json, 'poster_name'),
        verificationStatus: Json.str(json, 'verification_status', fallback: 'unverified'),
        matchedSkills: Json.intVal(json, 'matched_skills'),
        requiredSkills: Json.intVal(json, 'required_skills'),
        totalSkills: Json.intVal(json, 'total_skills'),
        matchingActive: Json.boolVal(json, 'matching_active'),
        isSaved: Json.boolVal(json, 'is_saved'),
        reportCount: Json.intVal(json, 'report_count'),
        isOwner: Json.boolVal(json, 'is_owner'),
        skills: Json.objectList(json, 'skills')
            .map(OpportunitySkill.fromJson)
            .toList(growable: false),
      );

  final String id;
  final String slug;
  final String kind;
  final String title;
  final String organisation;
  final String? summary;
  final String? description;
  final String? requirements;
  final String? benefits;
  final String locationTier;
  final String? locationText;
  final bool isRemote;
  final String? employmentType;
  final double? payMin;
  final double? payMax;
  final String payCurrency;
  final String? payPeriod;
  final String? payNote;
  final String? applicationUrl;
  final String? applicationEmail;
  final String? applicationPhone;
  final String? applicationNote;
  final String? closesAt;
  final String? posterName;

  /// Whether the archive has checked this listing. Shown, never merely stored:
  /// an unverified listing must look unverified.
  final String verificationStatus;

  final int matchedSkills;
  final int requiredSkills;
  final int totalSkills;

  /// Whether the member has any skills recorded at all. Without them the match
  /// numbers are meaningless and the page says so rather than showing zeroes.
  final bool matchingActive;

  final bool isSaved;
  final int reportCount;
  final bool isOwner;
  final List<OpportunitySkill> skills;

  bool get isVerified => verificationStatus == 'verified';

  String get kindLabel => switch (kind) {
        'job' => 'Job',
        'internship' => 'Internship',
        'apprenticeship' => 'Apprenticeship',
        'scholarship' => 'Scholarship',
        'grant' => 'Grant',
        'training' => 'Training',
        'volunteer' => 'Volunteering',
        'tender' => 'Tender',
        _ => 'Opportunity',
      };

  String get placeLabel {
    if (locationText != null && locationText!.isNotEmpty) return locationText!;
    return switch (locationTier) {
      'ekoli_yeden' => 'Ekoli-Yeden',
      'yakurr' => 'Yakurr',
      'cross_river' => 'Cross River',
      'nigeria' => 'Nigeria',
      'remote' => 'Remote',
      _ => 'Outside Nigeria',
    };
  }

  /// What it pays, in words, or null where the listing does not say.
  ///
  /// "What does it pay?" is the question most listings dodge and the one
  /// people most need answered, so it is shown prominently when present and
  /// its absence is stated rather than left blank.
  String? get payLabel {
    if (payMin == null && payMax == null) return null;

    final String period = switch (payPeriod) {
      'month' => ' a month',
      'year' => ' a year',
      'week' => ' a week',
      'day' => ' a day',
      'hour' => ' an hour',
      'once' => ' in total',
      _ => '',
    };

    String money(double amount) {
      if (amount >= 1000000) return '${(amount / 1000000).toStringAsFixed(1)}m';
      if (amount >= 1000) return '${(amount / 1000).round()}k';
      return amount.round().toString();
    }

    if (payMin != null && payMax != null && payMin != payMax) {
      return '$payCurrency ${money(payMin!)}–${money(payMax!)}$period';
    }
    return '$payCurrency ${money((payMin ?? payMax)!)}$period';
  }

  /// How well this fits, as a fraction — null when there is nothing to compare.
  double? get matchFraction {
    if (!matchingActive || totalSkills == 0) return null;
    return matchedSkills / totalSkills;
  }
}

class OpportunitySkill {
  const OpportunitySkill({
    required this.id,
    required this.name,
    this.isRequired = true,
    this.youHaveIt = false,
  });

  factory OpportunitySkill.fromJson(Map<String, dynamic> json) => OpportunitySkill(
        id: Json.str(json, 'id'),
        name: Json.str(json, 'name'),
        isRequired: Json.boolVal(json, 'is_required', fallback: true),
        youHaveIt: Json.boolVal(json, 'you_have_it'),
      );

  final String id;
  final String name;
  final bool isRequired;

  /// Whether the member reading this has recorded the skill. A gap is named
  /// rather than hidden — being told what to learn is more use than a listing
  /// that silently does not appear.
  final bool youHaveIt;
}

/// The choices the board offers, served so client and API cannot disagree.
class OpportunityOptions {
  const OpportunityOptions({
    this.kinds = const <({String value, String label})>[],
    this.tiers = const <({String value, String label})>[],
    this.employmentTypes = const <({String value, String label})>[],
    this.payPeriods = const <({String value, String label})>[],
    this.reportReasons = const <({String value, String label})>[],
  });

  factory OpportunityOptions.fromJson(Map<String, dynamic> json) {
    List<({String value, String label})> read(String key) => Json.objectList(json, key)
        .map((Map<String, dynamic> row) =>
            (value: Json.str(row, 'value'), label: Json.str(row, 'label')))
        .toList(growable: false);

    return OpportunityOptions(
      kinds: read('kinds'),
      tiers: read('tiers'),
      employmentTypes: read('employmentTypes'),
      payPeriods: read('payPeriods'),
      reportReasons: read('reportReasons'),
    );
  }

  final List<({String value, String label})> kinds;
  final List<({String value, String label})> tiers;
  final List<({String value, String label})> employmentTypes;
  final List<({String value, String label})> payPeriods;
  final List<({String value, String label})> reportReasons;
}

/// A listing somebody has reported, as a reviewer sees it.
///
/// The listing travels with the report — its title, who is offering it, and
/// where to open it. A queue of report ids is a queue nobody works through.
///
/// "It asks for money" is the reason that matters most here. A fraudulent
/// listing carrying this archive's name borrows its credibility to take
/// somebody's money, and that costs far more than a wrongly hidden job costs.
class OpportunityReport {
  const OpportunityReport({
    required this.id,
    required this.opportunityId,
    required this.reason,
    this.detail,
    this.reporterName,
    this.title,
    this.organisation,
    this.slug,
    this.state = 'open',
    this.reviewNote,
    this.createdAt,
  });

  factory OpportunityReport.fromJson(Map<String, dynamic> json) => OpportunityReport(
        id: Json.str(json, 'id'),
        opportunityId: Json.str(json, 'opportunity_id'),
        reason: Json.str(json, 'reason', fallback: 'other'),
        detail: Json.strOrNull(json, 'detail'),
        reporterName: Json.strOrNull(json, 'reporter_name'),
        title: Json.strOrNull(json, 'title'),
        organisation: Json.strOrNull(json, 'organisation'),
        slug: Json.strOrNull(json, 'slug'),
        state: Json.str(json, 'state', fallback: 'open'),
        reviewNote: Json.strOrNull(json, 'review_note'),
        createdAt: Json.strOrNull(json, 'created_at'),
      );

  final String id;
  final String opportunityId;
  final String reason;
  final String? detail;
  final String? reporterName;
  final String? title;
  final String? organisation;
  final String? slug;
  final String state;
  final String? reviewNote;
  final String? createdAt;

  /// The one that comes first, because it is the one that costs money.
  bool get isMoneyClaim => reason == 'asks_for_money';

  String get reasonLabel {
    switch (reason) {
      case 'asks_for_money':
        return 'It asks for money';
      case 'not_genuine':
        return 'Not genuine';
      case 'misleading':
        return 'Misleading';
      case 'expired':
        return 'Already closed';
      default:
        return 'Something else';
    }
  }
}
