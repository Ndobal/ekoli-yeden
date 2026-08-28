import '../core/constants/app_constants.dart';
import 'content_status.dart';
import 'gallery.dart';

/// AN AGE GRADE.
///
/// Not an article. A standing body with living members, its own officers and
/// its own news — which is why it carries people and posts rather than only a
/// title and a body of text.
///
/// A grade runs its own page. Whether the page exists publicly, and whether the
/// archive vouches for what it says, stay with the Preservation Team: the two
/// are different statements and the site keeps them apart.
class AgeGrade {
  const AgeGrade({
    required this.id,
    required this.slug,
    required this.title,
    required this.status,
    required this.verificationStatus,
    this.subtitle,
    this.formedYear,
    this.birthYears,
    this.excerpt,
    this.body,
    this.motto,
    this.contactName,
    this.contactPhone,
    this.contactEmail,
    this.coverMediaId,
    this.galleryId,
    this.adminRole,
    this.posts = const <AgeGradePost>[],
    this.postsTotal = 0,
    this.members = const <AgeGradeMember>[],
    this.administrators = const <AgeGradeAdmin>[],
    this.gallery = const <Photograph>[],
  });

  factory AgeGrade.fromJson(Map<String, dynamic> json) {
    return AgeGrade(
      id: Json.str(json, 'id'),
      slug: Json.str(json, 'slug'),
      title: Json.str(json, 'title', fallback: 'Age grade'),
      status: Json.str(json, 'status', fallback: ContentStatus.draft),
      verificationStatus: Json.str(
        json,
        'verification_status',
        fallback: VerificationStatus.unverified,
      ),
      subtitle: Json.strOrNull(json, 'subtitle'),
      formedYear: Json.intOrNull(json, 'formed_year'),
      birthYears: Json.strOrNull(json, 'birth_years'),
      excerpt: Json.strOrNull(json, 'excerpt'),
      body: Json.strOrNull(json, 'body'),
      motto: Json.strOrNull(json, 'motto'),
      contactName: Json.strOrNull(json, 'contact_name'),
      contactPhone: Json.strOrNull(json, 'contact_phone'),
      contactEmail: Json.strOrNull(json, 'contact_email'),
      coverMediaId: Json.strOrNull(json, 'cover_media_id'),
      galleryId: Json.strOrNull(json, 'gallery_id'),
      adminRole: Json.strOrNull(json, 'admin_role'),
      posts: Json.objectList(json, 'posts').map(AgeGradePost.fromJson).toList(growable: false),
      postsTotal: Json.intVal(json, 'posts_total'),
      members: Json.objectList(json, 'members').map(AgeGradeMember.fromJson).toList(growable: false),
      administrators: Json.objectList(json, 'administrators')
          .map(AgeGradeAdmin.fromJson)
          .toList(growable: false),
      gallery: Json.objectList(json, 'gallery').map(Photograph.fromJson).toList(growable: false),
    );
  }

  final String id;
  final String slug;
  final String title;
  final String status;
  final String verificationStatus;

  /// Any other name the grade is known by.
  final String? subtitle;

  /// The year it was formed, and the birth years it covers. Both may be
  /// unknown: for the older grades nobody now living may be certain, and a
  /// guessed year in an archive is worse than an empty field.
  final int? formedYear;
  final String? birthYears;

  final String? excerpt;
  final String? body;
  final String? motto;

  final String? contactName;
  final String? contactPhone;
  final String? contactEmail;
  final String? coverMediaId;
  final String? galleryId;

  /// `lead` or `admin` when this record came from "the grades I administer".
  final String? adminRole;

  final List<AgeGradePost> posts;
  final int postsTotal;
  final List<AgeGradeMember> members;
  final List<AgeGradeAdmin> administrators;
  final List<Photograph> gallery;

  bool get isPublished => status == ContentStatus.published;
  bool get isAwaitingConfirmation => status == ContentStatus.pendingReview;
  bool get isLead => adminRole == 'lead';

  /// "Formed 1994", or an honest silence.
  String? get formedLabel => formedYear == null ? null : 'Formed $formedYear';

  /// The line under the name on a card.
  String? get metaLine {
    final List<String> parts = <String>[
      if (formedYear != null) 'Formed $formedYear',
      ?birthYears,
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Something the grade has said about itself.
///
/// Published under the grade's own name rather than the archive's. The page
/// labels it as such, which is what keeps a grade's own account of itself from
/// being read as verified community history.
class AgeGradePost {
  const AgeGradePost({
    required this.id,
    required this.ageGradeId,
    required this.slug,
    required this.title,
    required this.postType,
    required this.status,
    this.excerpt,
    this.body,
    this.authorName,
    this.eventDate,
    this.publishedAt,
    this.createdAt,
    this.gradeSlug,
    this.gradeTitle,
  });

  factory AgeGradePost.fromJson(Map<String, dynamic> json) {
    return AgeGradePost(
      id: Json.str(json, 'id'),
      ageGradeId: Json.str(json, 'age_grade_id'),
      slug: Json.str(json, 'slug'),
      title: Json.str(json, 'title', fallback: 'Untitled'),
      postType: Json.str(json, 'post_type', fallback: 'update'),
      status: Json.str(json, 'status', fallback: ContentStatus.draft),
      excerpt: Json.strOrNull(json, 'excerpt'),
      body: Json.strOrNull(json, 'body'),
      authorName: Json.strOrNull(json, 'author_name'),
      eventDate: Json.strOrNull(json, 'event_date'),
      publishedAt: Json.strOrNull(json, 'published_at'),
      createdAt: Json.strOrNull(json, 'created_at'),
      // Present on the cross-grade activity feed, absent on a grade's own page.
      gradeSlug: Json.strOrNull(json, 'grade_slug'),
      gradeTitle: Json.strOrNull(json, 'grade_title'),
    );
  }

  final String id;
  final String ageGradeId;
  final String slug;
  final String title;
  final String postType;
  final String status;
  final String? excerpt;
  final String? body;
  final String? authorName;
  final String? eventDate;
  final String? publishedAt;
  final String? createdAt;
  final String? gradeSlug;
  final String? gradeTitle;

  bool get isPublished => status == ContentStatus.published;

  String get postTypeLabel => AgeGradePostTypes.label(postType);

  /// The date to show: what the post is about, or when it was written.
  String? get displayDate => eventDate ?? publishedAt ?? createdAt;
}

/// Somebody on the grade's roster.
///
/// Most members will never hold an account here, so the name is text. A living
/// person's name on a public page is personal data, which is why a new member
/// waits for confirmation.
class AgeGradeMember {
  const AgeGradeMember({
    required this.id,
    required this.ageGradeId,
    required this.fullName,
    required this.status,
    this.office,
    this.joinedYear,
    this.notes,
    this.isDeceased = false,
    this.deceasedYear,
  });

  factory AgeGradeMember.fromJson(Map<String, dynamic> json) {
    return AgeGradeMember(
      id: Json.str(json, 'id'),
      ageGradeId: Json.str(json, 'age_grade_id'),
      fullName: Json.str(json, 'full_name'),
      status: Json.str(json, 'status', fallback: ContentStatus.pendingReview),
      office: Json.strOrNull(json, 'office'),
      joinedYear: Json.intOrNull(json, 'joined_year'),
      notes: Json.strOrNull(json, 'notes'),
      isDeceased: Json.boolVal(json, 'is_deceased'),
      deceasedYear: Json.intOrNull(json, 'deceased_year'),
    );
  }

  final String id;
  final String ageGradeId;
  final String fullName;
  final String status;
  final String? office;
  final int? joinedYear;
  final String? notes;

  /// A grade's record of its own dead is part of what the grade is for.
  final bool isDeceased;
  final int? deceasedYear;

  bool get isPublished => status == ContentStatus.published;

  String? get metaLine {
    final List<String> parts = <String>[
      ?office,
      if (isDeceased) deceasedYear == null ? 'Late' : 'Late · $deceasedYear',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }
}

/// Somebody who may speak for the grade on this website.
///
/// `adminRole` is a fact about this site; `office` is a fact about the grade.
/// They are deliberately different fields — the Secretary of a grade is not
/// automatically the person who keeps its web page.
class AgeGradeAdmin {
  const AgeGradeAdmin({
    required this.displayName,
    required this.adminRole,
    this.userId,
    this.email,
    this.office,
  });

  factory AgeGradeAdmin.fromJson(Map<String, dynamic> json) {
    return AgeGradeAdmin(
      displayName: Json.str(json, 'display_name', fallback: 'Administrator'),
      adminRole: Json.str(json, 'admin_role', fallback: 'admin'),
      userId: Json.strOrNull(json, 'user_id'),
      // Only present in the grade's own workspace. The public page carries
      // names and offices, never contact details.
      email: Json.strOrNull(json, 'email'),
      office: Json.strOrNull(json, 'office'),
    );
  }

  final String displayName;
  final String adminRole;
  final String? userId;
  final String? email;
  final String? office;

  bool get isLead => adminRole == 'lead';

  String get roleLabel => isLead ? 'Lead administrator' : 'Administrator';
}

/// A grade's workspace: everything about it, drafts included, plus what the
/// person looking at it is actually allowed to do.
class AgeGradeWorkspace {
  const AgeGradeWorkspace({
    required this.grade,
    required this.posts,
    required this.members,
    required this.administrators,
    required this.canEdit,
    required this.canAppointAdmins,
  });

  factory AgeGradeWorkspace.fromJson(Map<String, dynamic> json) {
    final Map<String, dynamic> permissions =
        (json['permissions'] as Map<String, dynamic>?) ?? <String, dynamic>{};

    return AgeGradeWorkspace(
      grade: AgeGrade.fromJson((json['grade'] as Map<String, dynamic>?) ?? <String, dynamic>{}),
      posts: Json.objectList(json, 'posts').map(AgeGradePost.fromJson).toList(growable: false),
      members: Json.objectList(json, 'members').map(AgeGradeMember.fromJson).toList(growable: false),
      administrators: Json.objectList(json, 'administrators')
          .map(AgeGradeAdmin.fromJson)
          .toList(growable: false),
      // Mirrored so the workspace draws the right buttons. The server decides
      // again on every write regardless of what this says.
      canEdit: Json.boolVal(permissions, 'canEdit'),
      canAppointAdmins: Json.boolVal(permissions, 'canAppointAdmins'),
    );
  }

  final AgeGrade grade;
  final List<AgeGradePost> posts;
  final List<AgeGradeMember> members;
  final List<AgeGradeAdmin> administrators;
  final bool canEdit;
  final bool canAppointAdmins;
}
