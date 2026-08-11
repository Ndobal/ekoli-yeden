import { PRESERVATION_TEAM_POSITIONS, ROLES, type RoleSlug } from '../types/auth';

/**
 * THE EKOLI-YEDEN PRESERVATION TEAM
 *
 * The volunteer organisation that will actually fill this archive. Module 1
 * establishes its structure and the mapping from a volunteer's position to the
 * platform permissions that position needs — nothing more. No names, no
 * appointments and no membership are assumed here; those are recorded through
 * the admin system once the community has constituted the team.
 *
 * A member always has:
 *   • a position — what they do in the organisation (below), and
 *   • one or more platform roles — what the software lets them touch.
 *
 * Keeping the two separate means the community can reorganise its volunteers
 * without anybody rewriting the authorisation model.
 */

export interface PreservationTeamPositionDefinition {
  slug: string;
  title: string;
  /** What the position is responsible for within the organisation. */
  responsibility: string;
  /** Platform roles ordinarily granted to somebody holding this position. */
  suggestedRoles: RoleSlug[];
  /** Areas of the archive this position works on. */
  areas: string[];
}

/**
 * The areas of work the team is expected to manage.
 * These are the categories the admin system organises volunteer work into.
 */
export const PRESERVATION_AREAS = [
  'volunteers',
  'research',
  'historical_materials',
  'language_materials',
  'media',
  'verification',
  'community_contributions',
  'archives',
  'projects',
] as const;

export type PreservationArea = (typeof PRESERVATION_AREAS)[number];

export const PRESERVATION_TEAM: PreservationTeamPositionDefinition[] = [
  {
    slug: PRESERVATION_TEAM_POSITIONS.COORDINATOR,
    title: 'Coordinator',
    responsibility:
      'Leads the preservation team, sets priorities and represents the team to community leadership.',
    suggestedRoles: [ROLES.CONTENT_ADMINISTRATOR],
    areas: ['volunteers', 'projects', 'archives'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.SECRETARY,
    title: 'Secretary',
    responsibility: 'Keeps the record of meetings, decisions and the register of volunteers.',
    suggestedRoles: [ROLES.CONTENT_ADMINISTRATOR],
    areas: ['volunteers', 'archives'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.HISTORY_AND_RESEARCH,
    title: 'History & Research Team',
    responsibility:
      'Gathers and documents Ekoli-Yeden history, leadership records and historical materials, with sources.',
    suggestedRoles: [ROLES.HERITAGE_EDITOR],
    areas: ['research', 'historical_materials'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.LANGUAGE_PRESERVATION,
    title: 'Language Preservation Team',
    responsibility:
      'Collects Ekoli words, meanings, expressions and proverbs from native speakers and records pronunciation.',
    suggestedRoles: [ROLES.LANGUAGE_EDITOR],
    areas: ['language_materials', 'research'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.MEDIA,
    title: 'Media Team',
    responsibility:
      'Captures and catalogues photographs, audio and video, and maintains the YouTube archive.',
    suggestedRoles: [ROLES.MEDIA_MANAGER],
    areas: ['media', 'archives'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.TECHNOLOGY,
    title: 'Technology Team',
    responsibility: 'Maintains the platform, its deployments, backups and security.',
    suggestedRoles: [ROLES.SUPER_ADMIN],
    areas: ['archives', 'projects'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.VERIFICATION,
    title: 'Verification Team',
    responsibility:
      'Checks historical claims, leadership records and language entries before they are marked verified.',
    suggestedRoles: [ROLES.MODERATOR, ROLES.HERITAGE_EDITOR],
    areas: ['verification', 'research'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.COMMUNITY_OUTREACH,
    title: 'Community Outreach Team',
    responsibility:
      'Reaches elders, families and Ekoli-Yeden people abroad to collect materials and encourage contributions.',
    suggestedRoles: [ROLES.CONTRIBUTOR],
    areas: ['community_contributions', 'volunteers'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.ARCHIVE,
    title: 'Archive Team',
    responsibility:
      'Organises, labels and preserves accepted materials so they remain findable for future generations.',
    suggestedRoles: [ROLES.MEDIA_MANAGER, ROLES.HERITAGE_EDITOR],
    areas: ['archives', 'historical_materials', 'media'],
  },
  {
    slug: PRESERVATION_TEAM_POSITIONS.VOLUNTEER,
    title: 'Volunteer',
    responsibility: 'Contributes materials and assists the teams as needed.',
    suggestedRoles: [ROLES.CONTRIBUTOR],
    areas: ['community_contributions'],
  },
];

export function findPosition(slug: string): PreservationTeamPositionDefinition | undefined {
  return PRESERVATION_TEAM.find((position) => position.slug === slug);
}

export function isPreservationPosition(slug: string): boolean {
  return findPosition(slug) !== undefined;
}
