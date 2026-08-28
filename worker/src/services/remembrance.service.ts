import { RemembranceRepository, type DeathReportRecord } from '../repositories/remembrance.repository';
import { KinshipRepository } from '../repositories/kinship.repository';
import { GroupRepository } from '../repositories/group.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { SettingsRepository } from '../repositories/settings.repository';
import { AuditRepository } from '../repositories/audit.repository';
import { can } from './permissions';
import { RELATIONSHIP_LABELS } from './kinship';
import type { Env } from '../types/env';
import type { AuthenticatedUser } from '../types/auth';
import { BadRequestError, ConflictError, ForbiddenError, NotFoundError } from '../utils/errors';
import { nowIso } from '../utils/id';
import { slugify } from '../utils/slug';

/**
 * REMEMBRANCE
 *
 * When somebody dies, their account is stilled rather than deleted, what they
 * made public stays public, and they are remembered on a page of their own.
 *
 * ---------------------------------------------------------------------------
 * ALMOST ALL THE CARE IN THIS FILE IS ABOUT THE OTHER CASE
 * ---------------------------------------------------------------------------
 *
 * Recording a living person as dead is the most damaging thing anybody can do
 * here. It could be a mistake, a mix-up between two people with the same name,
 * or malice. Four things stand in the way, and none of them alone is enough:
 *
 *   1. A REPORT CHANGES NOTHING. It is a claim, held in `death_reports`, and
 *      the account is untouched until somebody else confirms it.
 *
 *   2. CONFIRMATION REQUIRES SOMEBODY WHO WAS ALREADY FAMILY. Not somebody
 *      claiming to be — an accepted relationship in `member_relationships`,
 *      close enough to plausibly know, accepted BEFORE the report was filed.
 *      Otherwise two accounts made this morning could bury somebody this
 *      afternoon.
 *
 *   3. THE ACCOUNT HOLDER IS TOLD AND CAN CONTEST IT. They are notified the
 *      moment a report is confirmed, and contesting takes one action.
 *
 *   4. THE ACCOUNT STAYS READABLE. Memorialisation makes it read-only, never
 *      locked. An account locked out of contesting its own death has no way to
 *      correct a mistake, and that would turn a recoverable error into a
 *      permanent one.
 *
 * The Preservation Team can stop or reverse any of it at any point.
 */
export class RemembranceService {
  private readonly remembrance: RemembranceRepository;
  private readonly kinship: KinshipRepository;
  private readonly groups: GroupRepository;
  private readonly settings: SettingsRepository;

  constructor(private readonly env: Env) {
    this.remembrance = new RemembranceRepository(env.DB);
    this.kinship = new KinshipRepository(env.DB);
    this.groups = new GroupRepository(env.DB);
    this.settings = new SettingsRepository(env.DB);
  }

  get repo(): RemembranceRepository {
    return this.remembrance;
  }

  // -------------------------------------------------------------------------
  // Reporting
  // -------------------------------------------------------------------------

  /**
   * Records that somebody has died. Changes nothing else.
   *
   * Open to a family member, an officer of a group the person belonged to, or
   * the Preservation Team. The reporter's claimed relationship is recorded as
   * a claim — the confirmation step is where a relationship actually has to
   * exist.
   */
  async report(
    actor: AuthenticatedUser,
    values: {
      subjectUserId: string | null;
      subjectName: string;
      relationship: string | null;
      groupId: string | null;
      dateOfDeath: string | null;
      placeOfDeath: string | null;
      detail: string | null;
    },
    context: { requestId: string },
  ): Promise<{ id: string; state: string; message: string }> {
    if (values.subjectUserId === actor.id) {
      throw new BadRequestError('You cannot report your own death.');
    }

    if (values.subjectUserId) {
      const open = await this.remembrance.openReportFor(values.subjectUserId);
      if (open) {
        throw new ConflictError(
          'Somebody has already reported this. You can confirm the existing report instead.',
        );
      }

      // The reporter must be family, an officer of a group they belonged to,
      // or the team. Anybody at all being able to file is a harassment channel.
      await this.assertMayReport(actor, values.subjectUserId, values.groupId);
    }

    const id = await this.remembrance.createReport({
      subjectUserId: values.subjectUserId,
      subjectName: values.subjectName,
      reportedBy: actor.id,
      reporterName: actor.displayName,
      reporterRelationship: values.relationship,
      groupId: values.groupId,
      dateOfDeath: values.dateOfDeath,
      placeOfDeath: values.placeOfDeath,
      detail: values.detail,
    });

    // The Preservation Team sees every report from the moment it is filed,
    // whether or not family ever confirm it.
    await this.notifyReviewers(
      'A death has been reported',
      `${values.subjectName}, reported by ${actor.displayName}.`,
      `/admin/remembrance/${id}`,
      id,
    );

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'remembrance.reported',
      resourceType: 'death_report',
      resourceId: id,
      changes: { subject: values.subjectName, subjectUserId: values.subjectUserId },
      requestId: context.requestId,
    });

    // A report about somebody with an account marks the profile as reported,
    // which is visible to them and to the team but changes nothing they can do.
    if (values.subjectUserId) {
      await this.remembrance.setMemorialState(values.subjectUserId, 'reported');
    }

    return {
      id,
      state: 'reported',
      message:
        'Thank you. This has been recorded and the Preservation Team has been told. Nothing on '
        + 'their account changes until a member of their family confirms it.',
    };
  }

  /**
   * Whether this person may file a report about that one.
   *
   * Family, an officer of a group the subject belonged to, or the team. The
   * relationship does not have to be close enough to CONFIRM — reporting and
   * confirming are different bars, and the person who hears first is often not
   * the closest relative.
   */
  private async assertMayReport(
    actor: AuthenticatedUser,
    subjectUserId: string,
    groupId: string | null,
  ): Promise<void> {
    if (can(actor, 'users:update')) return;

    const related = await this.kinship.between(actor.id, subjectUserId);
    if (related?.state === 'accepted') return;

    if (groupId) {
      const officer = await this.groups.adminFor(groupId, actor.id);
      const subjectBelongs = await this.groups.memberFor(groupId, subjectUserId);
      if (officer && subjectBelongs) return;
    }

    throw new ForbiddenError(
      'Only somebody connected to this person as family, or an officer of a group they belonged '
        + 'to, can report this. If neither applies, please contact the Preservation Team.',
    );
  }

  // -------------------------------------------------------------------------
  // Confirming
  // -------------------------------------------------------------------------

  /**
   * Confirms a report, and possibly memorialises the account.
   *
   * The safeguard lives here: `wasCloseFamilyBefore` requires an accepted,
   * close relationship that pre-dates the report. A Preservation Team member
   * may confirm without one, and that is recorded as an official confirmation
   * rather than a family one, so the two are told apart afterwards.
   */
  async confirm(
    actor: AuthenticatedUser,
    reportId: string,
    note: string | null,
    context: { requestId: string },
  ): Promise<{ state: string; message: string }> {
    const report = await this.remembrance.findReport(reportId);
    if (!report) throw new NotFoundError('That report was not found.');

    if (report.reported_by === actor.id) {
      throw new ForbiddenError(
        'The person who reported this cannot also confirm it. Somebody else in the family has to.',
      );
    }
    if (!['reported', 'family_confirmed'].includes(report.state)) {
      throw new BadRequestError('That report has already been settled.');
    }

    const isOfficial = can(actor, 'users:update');
    let relationshipId: string | null = null;
    let relationshipLabel: string | null = null;

    if (!isOfficial) {
      if (!report.subject_user_id) {
        throw new ForbiddenError(
          'Only the Preservation Team can confirm a record for somebody who had no account here.',
        );
      }

      const relationship = await this.kinship.wasCloseFamilyBefore(
        actor.id,
        report.subject_user_id,
        report.created_at,
      );

      if (!relationship) {
        throw new ForbiddenError(
          'Only close family can confirm this — and the connection has to have been recorded '
            + 'before the report was made. If you are family, please contact the Preservation Team.',
        );
      }

      relationshipId = relationship.id;
      const asSeen =
        relationship.from_user_id === actor.id
          ? relationship.type
          : (relationship.reverse_type ?? relationship.type);
      relationshipLabel = RELATIONSHIP_LABELS[asSeen] ?? asSeen;
    }

    await this.remembrance.addConfirmation({
      reportId,
      confirmedBy: actor.id,
      confirmerName: actor.displayName,
      relationshipId,
      relationship: relationshipLabel,
      isOfficial,
      note,
    });

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'remembrance.confirmed',
      resourceType: 'death_report',
      resourceId: reportId,
      changes: { official: isOfficial, relationship: relationshipLabel },
      requestId: context.requestId,
    });

    const required = await this.numberSetting('death_confirmations_required', 1);
    const familyConfirmations = await this.remembrance.familyConfirmationCount(reportId);

    if (!isOfficial && familyConfirmations < required) {
      return {
        state: 'reported',
        message: `Thank you. ${required - familyConfirmations} more confirmation from family is needed.`,
      };
    }

    return this.markFamilyConfirmed(report, actor, context);
  }

  /**
   * Confirmed. The account is stilled, and its holder is told.
   *
   * Told BEFORE the memorial page appears, and given a window to contest. If
   * the report is wrong, the person finds out from a notification on an account
   * they can still reach — which is the whole reason memorialisation does not
   * lock anybody out.
   */
  private async markFamilyConfirmed(
    report: DeathReportRecord,
    actor: AuthenticatedUser,
    context: { requestId: string },
  ): Promise<{ state: string; message: string }> {
    const contestHours = await this.numberSetting('death_contest_window_hours', 72);
    const closesAt = new Date(Date.now() + contestHours * 60 * 60 * 1000).toISOString();

    await this.remembrance.updateReport(report.id, {
      state: 'family_confirmed',
      subject_notified_at: report.subject_user_id ? nowIso() : null,
      contest_closes_at: report.subject_user_id ? closesAt : null,
    });

    if (report.subject_user_id) {
      await this.remembrance.setMemorialState(report.subject_user_id, 'memorialised');

      // The notification that makes this recoverable. Sent to the account
      // itself, which is still reachable precisely so this can arrive.
      await new NotificationRepository(this.env.DB).notify({
        userId: report.subject_user_id,
        kind: 'membership',
        title: 'This account has been recorded as memorialised',
        body:
          'Somebody has reported that the holder of this account has died, and a member of their '
          + 'family has confirmed it. If that is wrong, please say so — nothing has been deleted.',
        linkPath: '/account',
        resourceType: 'death_report',
        resourceId: report.id,
      });
    }

    await this.notifyReviewers(
      'A death report has been confirmed by family',
      `${report.subject_name}. The account is now read-only. Review before the memorial is published.`,
      `/admin/remembrance/${report.id}`,
      report.id,
    );

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'remembrance.family_confirmed',
      resourceType: 'death_report',
      resourceId: report.id,
      changes: { subject: report.subject_name, contestClosesAt: closesAt },
      requestId: context.requestId,
    });

    return {
      state: 'family_confirmed',
      message:
        'Confirmed. The account has been made read-only and the Preservation Team has been told. '
        + 'The memorial page is published once they have reviewed it.',
    };
  }

  // -------------------------------------------------------------------------
  // Contesting — the way back
  // -------------------------------------------------------------------------

  /**
   * "I am not dead."
   *
   * One action, available to the account holder at any point, with no deadline
   * enforced against them. It restores the account immediately and hands the
   * matter to the Preservation Team — because the cost of wrongly restoring a
   * genuinely deceased account for a day is nothing next to the cost of a
   * living person being unable to undo this.
   */
  async contest(
    actor: AuthenticatedUser,
    note: string | null,
    context: { requestId: string },
  ): Promise<{ message: string }> {
    const report = await this.remembrance.openReportFor(actor.id);
    if (!report) {
      throw new NotFoundError('There is no report about this account.');
    }

    await this.remembrance.updateReport(report.id, {
      state: 'contested',
      contested_at: nowIso(),
      contest_note: note,
    });

    // Restored at once, not after review.
    await this.remembrance.setMemorialState(actor.id, 'living');

    await this.notifyReviewers(
      'A memorialisation has been contested',
      `${actor.displayName} says the report about their account is wrong. The account has been `
        + 'restored and needs looking at.',
      `/admin/remembrance/${report.id}`,
      report.id,
    );

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'remembrance.contested',
      resourceType: 'death_report',
      resourceId: report.id,
      changes: { note },
      requestId: context.requestId,
    });

    return {
      message:
        'Your account has been restored and the Preservation Team has been told. We are sorry this '
        + 'happened.',
    };
  }

  /** What a memorialised or reported account sees when its holder signs in. */
  async noticeFor(userId: string): Promise<Record<string, unknown> | null> {
    const state = await this.remembrance.memorialStateOf(userId);
    if (state === 'living') return null;

    const report = await this.remembrance.openReportFor(userId);

    return {
      state,
      // Read-only, never locked. Stated in the response so the client cannot
      // accidentally present it as a lockout.
      can_sign_in: true,
      can_write: state !== 'memorialised',
      report_id: report?.id ?? null,
      reported_at: report?.created_at ?? null,
      contest_path: '/account/contest',
    };
  }

  // -------------------------------------------------------------------------
  // The memorial
  // -------------------------------------------------------------------------

  /**
   * Publishes the memorial page.
   *
   * The Preservation Team's decision, separate from the family confirmation
   * that stilled the account. Two different statements: "this person has died"
   * and "the archive now carries a page saying so".
   */
  async publishMemorial(
    actor: AuthenticatedUser,
    reportId: string,
    values: { biography: string | null; birthYear: number | null; groupId: string | null },
    context: { requestId: string },
  ): Promise<{ recordId: string; slug: string }> {
    const report = await this.remembrance.findReport(reportId);
    if (!report) throw new NotFoundError('That report was not found.');

    if (report.state === 'contested') {
      throw new BadRequestError(
        'This report has been contested by the account holder. It has to be settled first.',
      );
    }
    if (report.ancestry_record_id) {
      const existing = await this.remembrance.findAncestryRecord(report.ancestry_record_id);
      if (existing) return { recordId: existing.id, slug: existing.slug };
    }

    const deathYear = report.date_of_death
      ? Number(report.date_of_death.slice(0, 4)) || null
      : null;

    const recordId = await this.remembrance.createAncestryRecord({
      slug: await this.uniqueSlug(report.subject_name, deathYear),
      userId: report.subject_user_id,
      fullName: report.subject_name,
      birthYear: values.birthYear,
      birthDate: null,
      deathDate: report.date_of_death,
      deathYear,
      biography: values.biography,
      groupId: values.groupId ?? report.group_id,
      recordedBy: actor.id,
      deathReportId: reportId,
      portraitMediaId: null,
      status: 'published',
    });

    const record = await this.remembrance.findAncestryRecord(recordId);

    await this.remembrance.updateReport(reportId, {
      state: 'memorialised',
      ancestry_record_id: recordId,
      reviewed_by: actor.id,
      reviewed_at: nowIso(),
    });

    // Everybody in a group they belonged to is told, so the community learns of
    // it from the community rather than by stumbling on a page.
    if (report.group_id) {
      const fellows = await this.groups.memberUserIds(report.group_id);
      await new NotificationRepository(this.env.DB).notifyMany(
        fellows.filter((id) => id !== report.subject_user_id),
        {
          kind: 'general',
          title: `Remembering ${report.subject_name}`,
          body: 'A memorial has been recorded in the Ancestry Records.',
          linkPath: `/ancestry/${record?.slug ?? recordId}`,
          resourceType: 'ancestry',
          resourceId: recordId,
        },
      );
    }

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'remembrance.memorial_published',
      resourceType: 'ancestry_record',
      resourceId: recordId,
      changes: { subject: report.subject_name, reportId },
      requestId: context.requestId,
    });

    return { recordId, slug: record?.slug ?? recordId };
  }

  /**
   * Rejects a report and restores the account.
   *
   * The Preservation Team's undo, available at any stage — including after a
   * memorial has been published, because a mistake found late is still a
   * mistake to correct.
   */
  async reject(
    actor: AuthenticatedUser,
    reportId: string,
    reason: string | null,
    context: { requestId: string },
  ): Promise<void> {
    const report = await this.remembrance.findReport(reportId);
    if (!report) throw new NotFoundError('That report was not found.');

    await this.remembrance.updateReport(reportId, {
      state: 'rejected',
      reviewed_by: actor.id,
      reviewed_at: nowIso(),
      review_notes: reason,
    });

    if (report.subject_user_id) {
      await this.remembrance.setMemorialState(report.subject_user_id, 'living');

      await new NotificationRepository(this.env.DB).notify({
        userId: report.subject_user_id,
        kind: 'membership',
        title: 'Your account has been restored',
        body: 'The report about this account has been rejected. Nothing was deleted.',
        linkPath: '/account',
        resourceType: 'death_report',
        resourceId: reportId,
      });
    }

    // The memorial page comes down with it. A published memorial for a living
    // person is the harm this whole flow exists to avoid.
    if (report.ancestry_record_id) {
      await this.env.DB.prepare(
        `UPDATE "ancestry_records" SET "status" = 'archived', "updated_at" = ? WHERE "id" = ?`,
      )
        .bind(nowIso(), report.ancestry_record_id)
        .run();
    }

    await new AuditRepository(this.env.DB).record({
      actorId: actor.id,
      actorEmail: actor.email,
      action: 'remembrance.rejected',
      resourceType: 'death_report',
      resourceId: reportId,
      changes: { reason, restored: report.subject_user_id },
      requestId: context.requestId,
    });
  }

  // -------------------------------------------------------------------------

  private async notifyReviewers(
    title: string,
    body: string,
    linkPath: string,
    resourceId: string,
  ): Promise<void> {
    const result = await this.env.DB.prepare(
      `SELECT DISTINCT ur."user_id" FROM "user_roles" ur
       INNER JOIN "roles" r ON r."id" = ur."role_id"
       WHERE r."slug" IN ('super_admin', 'deputy_super_admin', 'moderator')`,
    ).all<{ user_id: string }>();

    const reviewers = (result.results ?? []).map((row) => row.user_id);
    if (reviewers.length === 0) return;

    await new NotificationRepository(this.env.DB).notifyMany(reviewers, {
      kind: 'membership',
      title,
      body,
      linkPath,
      resourceType: 'death_report',
      resourceId,
    });
  }

  private async numberSetting(key: string, fallback: number): Promise<number> {
    const setting = await this.settings.get(key).catch(() => null);
    const value = Number(setting?.value);
    return Number.isFinite(value) && value > 0 ? value : fallback;
  }

  private async uniqueSlug(name: string, deathYear: number | null): Promise<string> {
    const base = slugify(name) || 'remembered';
    const withYear = deathYear ? `${base}-${deathYear}` : base;

    if (!(await this.remembrance.ancestrySlugExists(withYear))) return withYear;
    for (let suffix = 2; suffix < 60; suffix += 1) {
      const candidate = `${withYear}-${suffix}`;
      if (!(await this.remembrance.ancestrySlugExists(candidate))) return candidate;
    }
    return `${withYear}-${Date.now()}`;
  }
}
