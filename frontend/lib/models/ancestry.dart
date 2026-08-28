/// ANCESTRY RECORDS — the people Ekoli-Yeden came from.
///
/// Every date field here is nullable, and that is the whole design. For the
/// older dead nobody now living may be certain of a year, and a guessed date on
/// a memorial is worse than an empty one — it becomes the archive's answer, and
/// the next person cites it. A page that says "the year is not recorded" is
/// telling the truth; a page that says 1943 because something had to go in the
/// field is not.
library;

import 'content_status.dart';

class AncestryRecord {
  const AncestryRecord({
    required this.id,
    required this.slug,
    required this.fullName,
    this.alsoKnownAs,
    this.birthYear,
    this.birthDate,
    this.deathYear,
    this.deathDate,
    this.biography,
    this.contribution,
    this.survivedBy,
    this.placeOfOrigin,
    this.quarter,
    this.groupTitle,
    this.groupSlug,
    this.portraitUrl,
    this.verificationStatus = 'unverified',
    this.tributes = const <Tribute>[],
    this.createdAt,
  });

  factory AncestryRecord.fromJson(Map<String, dynamic> json) => AncestryRecord(
    id: Json.str(json, 'id'),
    slug: Json.str(json, 'slug'),
    fullName: Json.str(json, 'full_name'),
    alsoKnownAs: Json.strOrNull(json, 'also_known_as'),
    birthYear: Json.intOrNull(json, 'birth_year'),
    birthDate: Json.strOrNull(json, 'birth_date'),
    deathYear: Json.intOrNull(json, 'death_year'),
    deathDate: Json.strOrNull(json, 'death_date'),
    biography: Json.strOrNull(json, 'biography'),
    contribution: Json.strOrNull(json, 'contribution'),
    survivedBy: Json.strOrNull(json, 'survived_by'),
    placeOfOrigin: Json.strOrNull(json, 'place_of_origin'),
    quarter: Json.strOrNull(json, 'quarter'),
    groupTitle: Json.strOrNull(json, 'group_title'),
    groupSlug: Json.strOrNull(json, 'group_slug'),
    portraitUrl: Json.strOrNull(json, 'portrait_url'),
    verificationStatus: Json.str(json, 'verification_status', fallback: 'unverified'),
    tributes: Json.objectList(json, 'tributes').map(Tribute.fromJson).toList(growable: false),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String slug;
  final String fullName;
  final String? alsoKnownAs;
  final int? birthYear;
  final String? birthDate;
  final int? deathYear;
  final String? deathDate;
  final String? biography;
  final String? contribution;
  final String? survivedBy;
  final String? placeOfOrigin;
  final String? quarter;
  final String? groupTitle;
  final String? groupSlug;
  final String? portraitUrl;
  final String verificationStatus;
  final List<Tribute> tributes;
  final String? createdAt;

  /// "1943 – 2019", "– 2019", or nothing at all.
  ///
  /// Never invents the missing half and never renders a dash on its own, so a
  /// record with neither year simply shows no dates rather than a stray mark
  /// that looks like a mistake.
  String? get lifespan {
    if (birthYear == null && deathYear == null) return null;
    if (birthYear != null && deathYear != null) return '$birthYear – $deathYear';
    if (deathYear != null) return 'died $deathYear';
    return 'born $birthYear';
  }

  bool get hasDates => birthYear != null || deathYear != null;

  /// Two letters for the portrait placeholder.
  String get initials {
    final List<String> parts = fullName
        .trim()
        .split(RegExp(r'\s+'))
        .where((String part) => part.isNotEmpty)
        .toList(growable: false);

    if (parts.isEmpty) return '—';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return parts.first.substring(0, 1).toUpperCase() +
        parts.last.substring(0, 1).toUpperCase();
  }
}

/// What somebody left on a memorial.
///
/// Signed by a name rather than linked to an account: a tribute is a person
/// speaking, and a memorial is not a place to send people off to somebody
/// else's profile.
class Tribute {
  const Tribute({
    required this.id,
    required this.authorName,
    required this.message,
    this.relationship,
    this.createdAt,
  });

  factory Tribute.fromJson(Map<String, dynamic> json) => Tribute(
    id: Json.str(json, 'id'),
    authorName: Json.str(json, 'author_name', fallback: 'A member of the community'),
    message: Json.str(json, 'message'),
    relationship: Json.strOrNull(json, 'relationship'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String authorName;
  final String message;
  final String? relationship;
  final String? createdAt;
}

/// A death report, as the Preservation Team sees it in their queue.
///
/// Four things stand between a report and a memorial, and this type carries
/// enough of each for a reviewer to see where one has got to: who said it, how
/// they say they are related, whether anybody who was already family has
/// confirmed it, and whether the person it is about has contested it.
class DeathReport {
  const DeathReport({
    required this.id,
    required this.subjectName,
    this.subjectUserId,
    this.reporterName,
    this.reporterRelationship,
    this.dateOfDeath,
    this.placeOfDeath,
    this.detail,
    this.state = 'reported',
    this.confirmations = 0,
    this.subjectNotifiedAt,
    this.contestClosesAt,
    this.contestedAt,
    this.contestNote,
    this.reviewNotes,
    this.createdAt,
  });

  factory DeathReport.fromJson(Map<String, dynamic> json) => DeathReport(
    id: Json.str(json, 'id'),
    subjectName: Json.str(json, 'subject_name'),
    subjectUserId: Json.strOrNull(json, 'subject_user_id'),
    reporterName: Json.strOrNull(json, 'reporter_name'),
    reporterRelationship: Json.strOrNull(json, 'reporter_relationship'),
    dateOfDeath: Json.strOrNull(json, 'date_of_death'),
    placeOfDeath: Json.strOrNull(json, 'place_of_death'),
    detail: Json.strOrNull(json, 'detail'),
    state: Json.str(json, 'state', fallback: 'reported'),
    confirmations: Json.intVal(json, 'confirmations'),
    subjectNotifiedAt: Json.strOrNull(json, 'subject_notified_at'),
    contestClosesAt: Json.strOrNull(json, 'contest_closes_at'),
    contestedAt: Json.strOrNull(json, 'contested_at'),
    contestNote: Json.strOrNull(json, 'contest_note'),
    reviewNotes: Json.strOrNull(json, 'review_notes'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String subjectName;
  final String? subjectUserId;
  final String? reporterName;
  final String? reporterRelationship;
  final String? dateOfDeath;
  final String? placeOfDeath;
  final String? detail;
  final String state;
  final int confirmations;
  final String? subjectNotifiedAt;
  final String? contestClosesAt;
  final String? contestedAt;
  final String? contestNote;
  final String? reviewNotes;
  final String? createdAt;

  /// The person it is about says it is wrong. Nothing else on this page
  /// matters until that is settled.
  bool get isContested => state == 'contested' || contestedAt != null;

  bool get isConfirmedByFamily => state == 'family_confirmed';
  bool get isMemorialised => state == 'memorialised';

  /// Whether the account holder has been told. Null where there was no account
  /// to tell, which is true of most of the community's dead.
  bool get hasAccount => subjectUserId != null;

  String get stateLabel {
    switch (state) {
      case 'reported':
        return 'Reported — not confirmed';
      case 'family_confirmed':
        return 'Confirmed by family';
      case 'memorialised':
        return 'Remembered';
      case 'contested':
        return 'Contested';
      case 'rejected':
        return 'Rejected';
      case 'withdrawn':
        return 'Withdrawn';
      default:
        return state;
    }
  }
}

/// What a reported or memorialised account is told when its holder signs in.
///
/// Null for everybody else, which is almost everybody — so a screen asks for
/// this once and renders nothing at all in the ordinary case.
///
/// `canSignIn` is always true and `canWrite` says whether the account is
/// read-only. The server states both rather than leaving the client to infer
/// them, because the one thing this screen must never do is present a
/// memorialised account as locked out: somebody locked out of contesting their
/// own death has no way to correct the mistake.
class MemorialNotice {
  const MemorialNotice({
    required this.state,
    this.canSignIn = true,
    this.canWrite = true,
    this.reportId,
    this.reportedAt,
  });

  factory MemorialNotice.fromJson(Map<String, dynamic> json) => MemorialNotice(
    state: Json.str(json, 'state', fallback: 'reported'),
    canSignIn: Json.boolVal(json, 'can_sign_in', fallback: true),
    canWrite: Json.boolVal(json, 'can_write', fallback: true),
    reportId: Json.strOrNull(json, 'report_id'),
    reportedAt: Json.strOrNull(json, 'reported_at'),
  );

  final String state;
  final bool canSignIn;
  final bool canWrite;
  final String? reportId;
  final String? reportedAt;

  bool get isMemorialised => state == 'memorialised';

  /// Reported but not yet acted on. The account is untouched at this stage,
  /// and saying so is what stops the notice reading as an accusation.
  bool get isReportedOnly => state == 'reported';
}
