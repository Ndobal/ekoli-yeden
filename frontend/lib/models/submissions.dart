/// WHAT THE COMMUNITY SENDS IN, AS A REVIEWER SEES IT.
///
/// Two structured contribution paths, and the queues that answer them: a
/// profile for the People section, and news for the community's own channel.
///
/// Both carry the contributor with them — name, how to reach them, and how they
/// know what they are telling us. That is not politeness. A reviewer deciding
/// what to do with a claim needs to know whether it comes from somebody who was
/// there or somebody who read it in a WhatsApp group, and an acknowledgement
/// that is lost at the moment of publication cannot be recovered afterwards.
library;

import 'content_status.dart';

/// A profile somebody has sent in for the People section.
class PersonSubmission {
  const PersonSubmission({
    required this.id,
    required this.reference,
    required this.name,
    this.alsoKnownAs,
    this.headline,
    this.profession,
    this.category,
    this.biography,
    this.achievements,
    this.birthYear,
    this.deathYear,
    this.isLiving,
    this.city,
    this.country,
    this.communityArea,
    this.websiteUrl,
    this.connectionToEkoli,
    this.whyNotable,
    this.consentBasis = 'unspecified',
    this.consentNote,
    this.consentContact,
    this.contributorName,
    this.contributorEmail,
    this.contributorPhone,
    this.contributorRelationship,
    this.status = 'pending_review',
    this.reviewNotes,
    this.createdAt,
  });

  factory PersonSubmission.fromJson(Map<String, dynamic> json) => PersonSubmission(
    id: Json.str(json, 'id'),
    reference: Json.str(json, 'reference_code'),
    name: Json.str(json, 'name'),
    alsoKnownAs: Json.strOrNull(json, 'also_known_as'),
    headline: Json.strOrNull(json, 'headline'),
    profession: Json.strOrNull(json, 'profession'),
    category: Json.strOrNull(json, 'category'),
    biography: Json.strOrNull(json, 'biography'),
    achievements: Json.strOrNull(json, 'achievements'),
    birthYear: Json.intOrNull(json, 'birth_year'),
    deathYear: Json.intOrNull(json, 'death_year'),
    isLiving: json['is_living'] == null ? null : Json.boolVal(json, 'is_living'),
    city: Json.strOrNull(json, 'city'),
    country: Json.strOrNull(json, 'country'),
    communityArea: Json.strOrNull(json, 'community_area'),
    websiteUrl: Json.strOrNull(json, 'website_url'),
    connectionToEkoli: Json.strOrNull(json, 'connection_to_ekoli'),
    whyNotable: Json.strOrNull(json, 'why_notable'),
    consentBasis: Json.str(json, 'consent_basis', fallback: 'unspecified'),
    consentNote: Json.strOrNull(json, 'consent_note'),
    consentContact: Json.strOrNull(json, 'consent_contact'),
    contributorName: Json.strOrNull(json, 'contributor_name'),
    contributorEmail: Json.strOrNull(json, 'contributor_email'),
    contributorPhone: Json.strOrNull(json, 'contributor_phone'),
    contributorRelationship: Json.strOrNull(json, 'contributor_relationship'),
    status: Json.str(json, 'status', fallback: 'pending_review'),
    reviewNotes: Json.strOrNull(json, 'review_notes'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String reference;
  final String name;
  final String? alsoKnownAs;
  final String? headline;
  final String? profession;
  final String? category;
  final String? biography;
  final String? achievements;
  final int? birthYear;
  final int? deathYear;

  /// Null where the contributor did not say. Null is not "no" — see
  /// [blocksPublication].
  final bool? isLiving;

  final String? city;
  final String? country;
  final String? communityArea;
  final String? websiteUrl;
  final String? connectionToEkoli;
  final String? whyNotable;

  /// How the archive may publish a page about this person.
  final String consentBasis;
  final String? consentNote;
  final String? consentContact;

  final String? contributorName;
  final String? contributorEmail;
  final String? contributorPhone;
  final String? contributorRelationship;

  final String status;
  final String? reviewNotes;
  final String? createdAt;

  /// The server refuses to publish a possibly-living person on an unspecified
  /// consent basis, and the queue says so before the reviewer presses anything.
  ///
  /// Note the `!= false`: a submission that does not say whether they are
  /// living is treated as though they might be. "We do not know" and "they have
  /// died" are different answers, and only one of them makes publishing safe.
  bool get blocksPublication => consentBasis == 'unspecified' && isLiving != false;

  String get consentLabel {
    switch (consentBasis) {
      case 'unspecified':
        return 'Not stated';
      case 'self':
        return 'They submitted it themselves';
      case 'family':
        return 'Their family gave it';
      case 'public_figure':
        return 'A public figure';
      case 'deceased':
        return 'They have died';
      case 'consent_given':
        return 'They agreed to it';
      default:
        return consentBasis;
    }
  }

  /// "1943 – 2019", or as much of it as is recorded.
  String? get lifespan {
    if (birthYear == null && deathYear == null) return null;
    if (birthYear != null && deathYear != null) return '$birthYear – $deathYear';
    if (deathYear != null) return 'died $deathYear';
    return 'born $birthYear';
  }
}

/// News somebody has sent in, waiting for an administrator.
class NewsSubmission {
  const NewsSubmission({
    required this.id,
    required this.reference,
    required this.title,
    required this.body,
    this.excerpt,
    this.category,
    this.happenedOn,
    this.location,
    this.contributorName,
    this.contributorEmail,
    this.contributorPhone,
    this.sourceNote,
    this.status = 'pending_review',
    this.reviewNotes,
    this.createdAt,
  });

  factory NewsSubmission.fromJson(Map<String, dynamic> json) => NewsSubmission(
    id: Json.str(json, 'id'),
    reference: Json.str(json, 'reference_code'),
    title: Json.str(json, 'title'),
    body: Json.str(json, 'body'),
    excerpt: Json.strOrNull(json, 'excerpt'),
    category: Json.strOrNull(json, 'category'),
    happenedOn: Json.strOrNull(json, 'happened_on'),
    location: Json.strOrNull(json, 'location'),
    contributorName: Json.strOrNull(json, 'contributor_name'),
    contributorEmail: Json.strOrNull(json, 'contributor_email'),
    contributorPhone: Json.strOrNull(json, 'contributor_phone'),
    sourceNote: Json.strOrNull(json, 'source_note'),
    status: Json.str(json, 'status', fallback: 'pending_review'),
    reviewNotes: Json.strOrNull(json, 'review_notes'),
    createdAt: Json.strOrNull(json, 'created_at'),
  );

  final String id;
  final String reference;
  final String title;
  final String body;
  final String? excerpt;
  final String? category;
  final String? happenedOn;
  final String? location;

  final String? contributorName;
  final String? contributorEmail;
  final String? contributorPhone;

  /// How they know. News from somebody who was there is a different thing from
  /// news read in a group chat, and this is the field that says which.
  final String? sourceNote;

  final String status;
  final String? reviewNotes;
  final String? createdAt;
}
