import { AgeGradeRepository, type AgeGradeRecord } from '../repositories/age-grade.repository';
import { SettingsRepository } from '../repositories/settings.repository';
import { UserRepository } from '../repositories/user.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { can } from './permissions';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { CONTENT_STATUS } from '../types/models';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from '../utils/errors';
import { nowIso } from '../utils/id';
import { slugify } from '../utils/slug';

/**
 * AGE GRADES THAT RUN THEMSELVES
 *
 * This file introduces one new authorisation axis, and it is deliberately the
 * narrowest in the platform: **administers this particular age grade**.
 *
 * It is not a platform role. It grants nothing anywhere else on the site. A
 * person who administers Ovat cannot touch Obam, cannot reach the media
 * library, cannot see a user list, cannot publish a history entry. The check
 * is one row in `age_grade_admins` for the specific grade being written to,
 * and that row is the whole of the power granted.
 *
 * WHAT THE GRADE CONTROLS, AND WHAT IT DOES NOT
 *
 *   The grade    its own description, its roster, its posts, its photographs
 *   The team     whether the grade exists publicly at all, and whether the
 *                archive vouches for what it says
 *
 * That split is why `updateOwnFields` cannot write `status` or
 * `verification_status`. A grade speaks for itself; it does not get to mark its
 * own account of itself as verified community history, and the public page
 * says which it is.
 */
export class AgeGradeService {
  private readonly repository: AgeGradeRepository;
  private readonly settings: SettingsRepository;

  constructor(private readonly env: Env) {
    this.repository = new AgeGradeRepository(env.DB);
    this.settings = new SettingsRepository(env.DB);
  }

  get repo(): AgeGradeRepository {
    return this.repository;
  }

  // -------------------------------------------------------------------------
  // Authorisation
  // -------------------------------------------------------------------------

  /**
   * Whether this person may act for this grade.
   *
   * Either they administer it, or they hold the platform permission to edit
   * age grades at all — which is how the Preservation Team steps in when a
   * grade's own administrator is unreachable.
   */
  async administrationOf(
    user: AuthenticatedUser | null,
    ageGradeId: string,
  ): Promise<{ isAdmin: boolean; isLead: boolean; viaPlatformPermission: boolean }> {
    if (!user) return { isAdmin: false, isLead: false, viaPlatformPermission: false };

    const platform = can(user, 'age-grades:update');
    const membership = await this.repository.adminFor(ageGradeId, user.id);

    return {
      isAdmin: membership !== null || platform,
      // A platform editor may act, but is not the grade's lead: appointing the
      // grade's own officers stays with the grade.
      isLead: membership?.admin_role === 'lead' || platform,
      viaPlatformPermission: platform && membership === null,
    };
  }

  async assertCanAdminister(user: AuthenticatedUser | null, ageGradeId: string): Promise<void> {
    const { isAdmin } = await this.administrationOf(user, ageGradeId);
    if (!isAdmin) {
      throw new ForbiddenError(
        'Only an administrator of this age grade can make that change. If you belong to this '
          + 'grade, ask one of its administrators to add you.',
      );
    }
  }

  async assertIsLead(user: AuthenticatedUser | null, ageGradeId: string): Promise<void> {
    const { isLead } = await this.administrationOf(user, ageGradeId);
    if (!isLead) {
      throw new ForbiddenError(
        'Only the lead administrator of this age grade can appoint or remove an administrator.',
      );
    }
  }

  // -------------------------------------------------------------------------
  // Registering a grade
  // -------------------------------------------------------------------------

  /**
   * Registers an age grade, with the person who registered it as its lead.
   *
   * The grade starts at `pending_review`. A page that claims to speak for a
   * body of the community should be confirmed by somebody before it goes live,
   * and that is the one gate worth keeping — after it, the grade runs itself.
   */
  async register(
    values: {
      title: string;
      subtitle: string | null;
      formedYear: number | null;
      birthYears: string | null;
      excerpt: string | null;
      body: string | null;
      motto: string | null;
      contactName: string | null;
      contactPhone: string | null;
      contactEmail: string | null;
      office: string | null;
    },
    registrar: AuthenticatedUser,
    context: { requestId: string },
  ): Promise<{ id: string; slug: string; status: string }> {
    if (!(await this.settingEnabled('age_grades_self_registration', true))) {
      throw new ForbiddenError(
        'Age grade registration is closed at the moment. Please contact the Preservation Team.',
      );
    }

    // Refused only when the same grade appears to be registered twice: same
    // name, same year of formation. A grade re-formed under an old name a
    // generation later is a different grade and gets its own page, which is
    // why the year is part of the comparison rather than the name alone.
    const duplicate = await this.findDuplicate(values.title, values.formedYear);
    if (duplicate) {
      throw new ConflictError(
        `"${duplicate.title}" is already registered. If that is your grade, ask one of its `
          + 'administrators to add you rather than registering it a second time.',
      );
    }

    const slug = await this.uniqueSlug(values.title, values.formedYear);

    const id = await this.repository.create({
      slug,
      title: values.title,
      subtitle: values.subtitle,
      formedYear: values.formedYear,
      birthYears: values.birthYears,
      excerpt: values.excerpt,
      body: values.body,
      motto: values.motto,
      contactName: values.contactName ?? registrar.displayName,
      contactPhone: values.contactPhone,
      contactEmail: values.contactEmail ?? registrar.email,
      createdBy: registrar.id,
      status: CONTENT_STATUS.PENDING_REVIEW,
    });

    // The registrar becomes the lead in the same operation. A grade with no
    // administrator is a grade nobody can correct.
    await this.repository.addAdmin({
      ageGradeId: id,
      userId: registrar.id,
      adminRole: 'lead',
      office: values.office,
      appointedBy: registrar.id,
    });

    await new AuditRepository(this.env.DB).record({
      actorId: registrar.id,
      actorEmail: registrar.email,
      action: 'age_grade.registered',
      resourceType: 'age_grade',
      resourceId: id,
      changes: { title: values.title, formedYear: values.formedYear, slug },
      requestId: context.requestId,
    });

    return { id, slug, status: CONTENT_STATUS.PENDING_REVIEW };
  }

  // -------------------------------------------------------------------------
  // Administrators
  // -------------------------------------------------------------------------

  /**
   * Appoints another administrator, by email address.
   *
   * By email rather than by user id because the lead knows their age-mate's
   * email and has no way to know an internal identifier. The account has to
   * exist already: creating one on somebody's behalf is an administrative act,
   * not something an age grade should be able to do.
   */
  async appointAdmin(
    ageGradeId: string,
    email: string,
    options: { adminRole: 'lead' | 'admin'; office: string | null },
    actor: AuthenticatedUser,
    context: { requestId: string },
  ): Promise<{ userId: string; displayName: string }> {
    await this.assertIsLead(actor, ageGradeId);

    const users = new UserRepository(this.env.DB);
    const user = await users.findByEmail(email);
    if (!user) {
      throw new NotFoundError(
        'No account exists for that email address. Ask them to register first, then appoint them.',
      );
    }

    await this.repository.addAdmin({
      ageGradeId,
      userId: user.id,
      adminRole: options.adminRole,
      office: options.office,
      appointedBy: actor.id,
    });

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'age_grade.admin.appointed',
      resourceType: 'age_grade',
      resourceId: ageGradeId,
      changes: { appointed: user.email, role: options.adminRole, office: options.office },
      requestId: context.requestId,
    });

    return { userId: user.id, displayName: user.display_name };
  }

  /**
   * Removes an administrator.
   *
   * The last lead cannot be removed. The same reasoning as the last Super
   * Admin: a grade with no lead is a grade nobody can hand on, and the fix
   * would need somebody outside it to intervene.
   */
  async removeAdmin(
    ageGradeId: string,
    userId: string,
    actor: AuthenticatedUser,
    context: { requestId: string },
  ): Promise<void> {
    await this.assertIsLead(actor, ageGradeId);

    const target = await this.repository.adminFor(ageGradeId, userId);
    if (!target) throw new NotFoundError('That person does not administer this age grade.');

    if (target.admin_role === 'lead' && (await this.repository.countLeads(ageGradeId)) <= 1) {
      throw new BadRequestError(
        'This is the only lead administrator of this age grade. Appoint another lead first, so the '
          + 'grade is never left without one.',
      );
    }

    await this.repository.removeAdmin(ageGradeId, userId);

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'age_grade.admin.removed',
      resourceType: 'age_grade',
      resourceId: ageGradeId,
      changes: { removed: userId },
      requestId: context.requestId,
    });
  }

  // -------------------------------------------------------------------------
  // Posts
  // -------------------------------------------------------------------------

  /**
   * The status a new post takes.
   *
   * Published by default, because an update that has to wait a week for a
   * volunteer editor is an update that stops being written. The community can
   * turn that off with one setting, and the public page always labels a post
   * as the grade's own words rather than verified community history — so the
   * archive's honesty does not depend on the review queue.
   */
  async statusForNewPost(): Promise<string> {
    return (await this.settingEnabled('age_grade_posts_require_review', false))
      ? CONTENT_STATUS.PENDING_REVIEW
      : CONTENT_STATUS.PUBLISHED;
  }

  async statusForNewMember(): Promise<string> {
    return (await this.settingEnabled('age_grade_members_require_review', true))
      ? CONTENT_STATUS.PENDING_REVIEW
      : CONTENT_STATUS.PUBLISHED;
  }

  /** A post slug unique within its grade. */
  async uniquePostSlug(ageGradeId: string, title: string): Promise<string> {
    const root = slugify(title) || `post-${Date.now()}`;
    if (!(await this.repository.postSlugExists(ageGradeId, root))) return root;

    for (let suffix = 2; suffix < 50; suffix += 1) {
      const candidate = `${root}-${suffix}`;
      if (!(await this.repository.postSlugExists(ageGradeId, candidate))) return candidate;
    }
    return `${root}-${Date.now()}`;
  }

  /** Resolves a grade for a public reader, or fails with a 404. */
  async publicGrade(identifier: string): Promise<AgeGradeRecord> {
    const grade = await this.repository.findBySlugOrId(identifier, [CONTENT_STATUS.PUBLISHED]);
    if (!grade) {
      throw new NotFoundError(
        'That age grade has not been published yet. If it is yours, it may still be waiting for '
          + 'the Preservation Team to confirm it.',
      );
    }
    return grade;
  }

  /** Resolves a grade for somebody who may administer it, in any status. */
  async manageableGrade(identifier: string): Promise<AgeGradeRecord> {
    const grade = await this.repository.findBySlugOrId(identifier, null);
    if (!grade) throw new NotFoundError('That age grade was not found.');
    return grade;
  }

  // -------------------------------------------------------------------------

  /**
   * An already-registered grade with the same name and the same formed year.
   *
   * Both slug shapes are checked because a grade registered before anybody
   * knew its year carries the bare name, and one registered afterwards carries
   * the year — the same grade reaching the same page by two routes.
   */
  private async findDuplicate(title: string, formedYear: number | null): Promise<AgeGradeRecord | null> {
    const base = slugify(title);
    if (base === '') return null;

    const candidates = formedYear ? [`${base}-${formedYear}`, base] : [base];
    for (const slug of candidates) {
      const found = await this.repository.findBySlugOrId(slug, null);
      if (!found) continue;
      // A grade with no recorded year cannot be told apart from a new one that
      // has none either, so a name match is treated as the same grade.
      if (found.formed_year === formedYear || found.formed_year === null || formedYear === null) {
        return found;
      }
    }
    return null;
  }

  private async settingEnabled(key: string, fallback: boolean): Promise<boolean> {
    const setting = await this.settings.get(key).catch(() => null);
    if (!setting || setting.value === null) return fallback;
    return setting.value === 'true' || setting.value === '1';
  }

  /**
   * A slug for a grade.
   *
   * The formed year is folded in where there is one, because grades are
   * sometimes re-formed under the same name a generation apart and both
   * deserve their own address.
   */
  private async uniqueSlug(title: string, formedYear: number | null): Promise<string> {
    const base = slugify(title) || 'age-grade';
    const withYear = formedYear ? `${base}-${formedYear}` : base;

    if (!(await this.repository.slugExists(withYear))) return withYear;
    if (!(await this.repository.slugExists(base))) return base;

    for (let suffix = 2; suffix < 50; suffix += 1) {
      const candidate = `${withYear}-${suffix}`;
      if (!(await this.repository.slugExists(candidate))) return candidate;
    }
    return `${withYear}-${nowIso().slice(0, 10)}`;
  }
}
