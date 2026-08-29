/**
 * YAKOLI MEMBERSHIP — the vocabulary, and the rules about what may be seen.
 *
 * Kept apart from the repository and the controller because these are
 * decisions rather than data access: how a work situation is grouped, what a
 * stranger may read off a profile, how complete a profile is. Every one of them
 * is a rule the community could reasonably want to change, and they should be
 * changeable in one place.
 */

/**
 * How somebody describes their current work situation.
 *
 * Asked this way — "what best describes your current work situation?" — rather
 * than "are you unemployed?". The difference is not politeness. A person
 * running a small business, a person between contracts and a person who has
 * retired are three different situations that a yes/no question flattens into
 * one, and the flattened answer is both less useful and more insulting.
 */
export const EMPLOYMENT_STATUSES = [
  'employed_full_time',
  'employed_part_time',
  'self_employed',
  'business_owner',
  'freelancer',
  'student',
  'seeking_work',
  'not_seeking',
  'retired',
  'other',
] as const;

export type EmploymentStatus = (typeof EMPLOYMENT_STATUSES)[number];

export const EMPLOYMENT_LABELS: Record<EmploymentStatus, string> = {
  employed_full_time: 'Employed — full time',
  employed_part_time: 'Employed — part time',
  self_employed: 'Self-employed',
  business_owner: 'Business owner',
  freelancer: 'Freelancer or contract worker',
  student: 'Student',
  seeking_work: 'Actively seeking work',
  not_seeking: 'Not currently working, and not seeking',
  retired: 'Retired',
  other: 'Other',
};

/** The five buckets the platform reasons about. */
export type WorkGroup = 'working' | 'seeking' | 'student' | 'retired' | 'not_working' | 'unknown';

const WORK_GROUPS: Record<EmploymentStatus, WorkGroup> = {
  employed_full_time: 'working',
  employed_part_time: 'working',
  self_employed: 'working',
  business_owner: 'working',
  freelancer: 'working',
  student: 'student',
  seeking_work: 'seeking',
  retired: 'retired',
  not_seeking: 'not_working',
  other: 'not_working',
};

export const WORK_GROUP_LABELS: Record<WorkGroup, string> = {
  working: 'Working',
  seeking: 'Seeking employment',
  student: 'Student',
  retired: 'Retired',
  not_working: 'Not working',
  unknown: 'Not said',
};

/**
 * Derived rather than stored.
 *
 * A stored group would be a second copy of the same fact, and the two would
 * eventually disagree — most likely on the day somebody adds a status and
 * forgets to backfill. There is one source of truth and it is the column the
 * member actually set.
 */
export function workGroupFor(status: string | null | undefined): WorkGroup {
  if (!status) return 'unknown';
  return WORK_GROUPS[status as EmploymentStatus] ?? 'unknown';
}

/**
 * WHAT SOMEBODY IS TO EKOLI-YEDEN.
 *
 * ---------------------------------------------------------------------------
 * THIS IS NOT A ROLE, AND THE TWO MUST NOT BE MERGED
 * ---------------------------------------------------------------------------
 *
 * A person on this platform has two independent facts about them:
 *
 *   what they ARE to Ekoli-Yeden   — indigene, resident, friend, researcher
 *   what they DO on the platform   — user, contributor, editorial, admin
 *
 * They do not vary together. An indigene may be an ordinary user or the Super
 * Admin; a researcher from a university may be a contributor; a friend of the
 * community may run the media library. Folding them into one word forces every
 * such person to be described as something they are not.
 *
 * So this grants nothing. It is recorded, it is shown on a profile where the
 * person chose to show it, and it is what the Indigene Directory filters by.
 * Every permission decision reads `roles` and nothing here.
 *
 * `married_in` is the seventh where six were suggested. The community already
 * makes that distinction, and collapsing it into either "indigene" or
 * "resident" would have the archive decide which a woman who married into
 * Ekori is. That is not the platform's decision to make.
 */
export const EKOLI_RELATIONSHIPS = [
  'indigene',
  'resident',
  'married_in',
  'friend',
  'researcher',
  'organisation',
  'other',
] as const;

export type EkoliRelationship = (typeof EKOLI_RELATIONSHIPS)[number];

export const EKOLI_RELATIONSHIP_LABELS: Record<string, string> = {
  indigene: 'Indigene of Ekoli-Yeden',
  resident: 'Resident of Ekoli-Yeden',
  married_in: 'Married into Ekoli-Yeden',
  friend: 'Friend and supporter',
  researcher: 'Researcher or academic',
  organisation: 'Organisation or institution',
  other: 'Something else',
};

/**
 * The older, longer list.
 *
 * Kept because `connection` still holds these values on profiles filled in
 * before 0033, and because the distinctions in it — born here, family from
 * here, returned — are a story worth keeping even now that the relationship
 * field says "indigene" for all three.
 */
export const CONNECTIONS = [
  'born_here',
  'family_from_here',
  'married_into',
  'resident',
  'descendant',
  'returned',
  'researcher',
  'friend',
  'other',
] as const;

export const CONNECTION_LABELS: Record<string, string> = {
  born_here: 'Born in Ekoli-Yeden',
  family_from_here: 'My family is from Ekoli-Yeden',
  married_into: 'Married into Ekoli-Yeden',
  resident: 'I live in Ekoli-Yeden',
  descendant: 'A descendant of Ekoli-Yeden',
  returned: 'I have returned to Ekoli-Yeden',
  researcher: 'A researcher or scholar',
  friend: 'A friend of the community',
  other: 'Something else',
};

export const EDUCATION_LEVELS = [
  'primary',
  'secondary',
  'vocational',
  'diploma',
  'bachelors',
  'masters',
  'doctorate',
  'other',
] as const;

export const EDUCATION_LABELS: Record<string, string> = {
  primary: 'Primary',
  secondary: 'Secondary',
  vocational: 'Vocational or trade training',
  diploma: 'Diploma or certificate',
  bachelors: "Bachelor's degree",
  masters: "Master's degree",
  doctorate: 'Doctorate',
  other: 'Other',
};

export const PROFILE_VISIBILITIES = ['public', 'members', 'private'] as const;
export type ProfileVisibility = (typeof PROFILE_VISIBILITIES)[number];

export const PROFICIENCIES = ['unspecified', 'beginner', 'intermediate', 'advanced', 'expert'] as const;

// ---------------------------------------------------------------------------
// What a given viewer may see
// ---------------------------------------------------------------------------

/** Who is looking at a profile. */
export type ViewerRelationship = 'self' | 'member' | 'stranger' | 'administrator';

/**
 * Strips a profile down to what this viewer is allowed to read.
 *
 * The single most important function in the membership module, and the reason
 * it is a function rather than a set of conditionals scattered through the
 * controllers: every route that returns a profile goes through here, so a new
 * endpoint cannot leak a phone number by forgetting a check.
 *
 * The rules:
 *
 *   self / administrator   everything
 *   member                 the profile if it is public or members-only,
 *                          plus whatever fields the member switched on
 *   stranger               the profile only if it is public, and then only the
 *                          fields switched on — never contact details, never a
 *                          work situation, never a birth year
 *
 * `null` means "you may not see this at all", which the caller turns into a
 * 404 rather than a 403: whether a private profile exists is itself private.
 */
export function visibleProfile(
  profile: Record<string, unknown>,
  viewer: ViewerRelationship,
  /**
   * What this particular reader has been given permission to see, from
   * `contact_grants`. Defaults to nothing, so a caller that forgets to pass it
   * shows less rather than more — the only safe direction for this argument to
   * fail in.
   */
  grant: { phone: boolean; email: boolean } = { phone: false, email: false },
): Record<string, unknown> | null {
  if (viewer === 'self' || viewer === 'administrator') return withDerived(profile);

  const visibility = String(profile['profile_visibility'] ?? 'members');
  if (visibility === 'private') return null;
  if (visibility === 'members' && viewer !== 'member') return null;

  const showContact = profile['show_contact'] === 1;
  const showEmployment = profile['show_employment'] === 1;
  const showLocation = profile['show_location'] === 1;
  const showEducation = profile['show_education'] === 1;

  const shaped: Record<string, unknown> = {
    id: profile['id'],
    handle: profile['handle'],
    membership_number: profile['membership_number'],
    membership_status: profile['membership_status'],
    joined_at: profile['joined_at'],
    full_name: profile['full_name'],
    headline: profile['headline'],
    bio: profile['bio'],
    avatar_url: profile['avatar_url'] ?? null,
    cover_url: profile['cover_url'] ?? null,
    connection: profile['connection'],
    connection_note: profile['connection_note'],
    // Shown to anybody who may see the profile at all. What somebody is to
    // Ekoli-Yeden is the least private thing about them and the reason most
    // people are here — it is not hidden behind the contact switches.
    relationship: profile['relationship'],
    relationship_label:
      typeof profile['relationship'] === 'string'
        ? (EKOLI_RELATIONSHIP_LABELS[profile['relationship']] ?? null)
        : null,
    profession_id: profile['profession_id'],
    profession: profile['profession'] ?? null,
    profession_other: profile['profession_other'],
    industry: profile['industry'],
    years_experience: profile['years_experience'],
    skills: profile['skills'] ?? [],
    interests: profile['interests'] ?? [],
    profile_visibility: visibility,
    listed_in_directory: profile['listed_in_directory'],
  };

  if (showLocation) {
    shaped['country'] = profile['country'];
    shaped['state_region'] = profile['state_region'];
    shaped['lga'] = profile['lga'];
    shaped['city'] = profile['city'];
    shaped['community_area'] = profile['community_area'];
    shaped['is_in_ekoli_yeden'] = profile['is_in_ekoli_yeden'];
    shaped['is_diaspora'] = profile['is_diaspora'];
    // Where in Ekori they are from, in their own words, and their clan.
    //
    // Under `show_location` with the rest of it: which compound somebody is
    // from is how the community places a person, and it is exactly as personal
    // as the town they live in. `place_text` rather than the matched place —
    // what they said about their own home is the thing to show.
    shaped['place_text'] = profile['place_text'];
    shaped['clan'] = profile['clan'];
  }

  if (showEducation) {
    shaped['education_level'] = profile['education_level'];
    shaped['education_field'] = profile['education_field'];
    shaped['institution'] = profile['institution'];
  }

  // The employment rule, in one place.
  //
  // Even switched on, `seeking_work` and `not_seeking` are reported as the
  // neutral "open to opportunities" rather than as a status. The platform does
  // not publish that somebody is out of work — not to a stranger, not to
  // another member, not anywhere. The full status exists for matching and for
  // aggregate statistics, and stays there.
  if (showEmployment) {
    const status = String(profile['employment_status'] ?? '');
    const group = workGroupFor(status);
    if (group === 'working' || group === 'student' || group === 'retired') {
      shaped['employment_status'] = status;
      shaped['work_group'] = group;
      shaped['employer'] = profile['employer'];
    }
  }
  shaped['open_to_opportunities'] = profile['open_to_opportunities'];

  // Mentoring is an offer the member is making to the community, so it travels
  // with the profile rather than sitting behind the contact gates. The note is
  // only meaningful when the offer is on, and is dropped otherwise so a stale
  // sentence from a member who has since switched it off cannot linger.
  const mentoring = Number(profile['open_to_mentoring'] ?? 0) === 1;
  shaped['open_to_mentoring'] = mentoring;
  shaped['mentoring_note'] = mentoring ? profile['mentoring_note'] : null;

  // ---------------------------------------------------------------------
  // CONTACT DETAILS. TWO GATES, AND BOTH MUST OPEN.
  // ---------------------------------------------------------------------
  //
  // `show_contact` is the member saying "anybody who may see my profile may
  // see how to reach me". Most people leave it off, and that is the right
  // default.
  //
  // `grant` is the member having said yes to one particular person who asked.
  // It is a row in `contact_grants`, written only by the person whose details
  // they are, and read here on every shaping — never cached, so taking it back
  // works on the next request rather than whenever something notices.
  //
  // Either opens the gate for the field it covers. Neither is inferred from
  // anything else: not from a conversation existing, not from being family,
  // not from being in the same age grade. Somebody being reachable and
  // somebody's number being public are different things, and this platform's
  // whole messaging design rests on keeping them apart.
  const phoneAllowed = showContact || grant.phone;
  const emailAllowed = showContact || grant.email;

  if (phoneAllowed) {
    shaped['phone'] = profile['phone'];
    shaped['whatsapp_number'] = profile['whatsapp_number'];
  }
  if (emailAllowed) {
    shaped['email'] = profile['email'] ?? null;
  }

  // Stated rather than left to be inferred from an absent field, so a profile
  // can offer "ask for their number" instead of silently showing nothing.
  shaped['contact_hidden'] = !phoneAllowed && !emailAllowed;
  shaped['contact_shared_with_me'] = grant.phone || grant.email;

  // Never exposed to anybody but the member and an administrator, whatever the
  // switches say: a birth year is identifying and nothing on the public side of
  // this platform needs it.
  return shaped;
}

/** Adds the fields computed from stored ones, for the member's own view. */
function withDerived(profile: Record<string, unknown>): Record<string, unknown> {
  return {
    ...profile,
    work_group: workGroupFor(profile['employment_status'] as string | null),
    work_group_label: WORK_GROUP_LABELS[workGroupFor(profile['employment_status'] as string | null)],
  };
}

// ---------------------------------------------------------------------------
// Profile completeness
// ---------------------------------------------------------------------------

/**
 * How much of a profile is filled in.
 *
 * Weighted by what the platform can actually do with each field rather than by
 * counting columns: skills and location are what make the opportunities board
 * and the directory work, so they are worth more than a headline.
 *
 * Shown to the member as a nudge. Never shown to anybody else — "this person's
 * profile is 30% complete" is not a fact about them that others need.
 */
export function completionPercent(
  profile: Record<string, unknown>,
  counts: { skills: number; interests: number },
): number {
  const checks: { filled: boolean; weight: number }[] = [
    { filled: isFilled(profile['full_name']), weight: 15 },
    { filled: isFilled(profile['connection']), weight: 10 },
    { filled: isFilled(profile['country']), weight: 10 },
    { filled: isFilled(profile['state_region']) || isFilled(profile['community_area']), weight: 10 },
    { filled: isFilled(profile['profession_id']) || isFilled(profile['profession_other']), weight: 15 },
    { filled: counts.skills > 0, weight: 15 },
    { filled: isFilled(profile['employment_status']), weight: 10 },
    { filled: counts.interests > 0, weight: 5 },
    { filled: isFilled(profile['headline']) || isFilled(profile['bio']), weight: 5 },
    { filled: isFilled(profile['avatar_media_id']), weight: 5 },
  ];

  const earned = checks.reduce((sum, check) => sum + (check.filled ? check.weight : 0), 0);
  return Math.min(100, Math.max(0, earned));
}

function isFilled(value: unknown): boolean {
  if (value === null || value === undefined) return false;
  if (typeof value === 'string') return value.trim() !== '';
  return true;
}

// ---------------------------------------------------------------------------
// Location
// ---------------------------------------------------------------------------

/**
 * The proximity tiers Module 6 sorts opportunities by.
 *
 * Ordered from "here" outwards. A member in Ekoli-Yeden should not have to
 * scroll past two hundred jobs in another country to find the one down the
 * road.
 */
export const LOCATION_TIERS = [
  'ekoli_yeden',
  'yakurr',
  'cross_river',
  'nigeria',
  'remote',
  'international',
] as const;

export type LocationTier = (typeof LOCATION_TIERS)[number];

/** Names that mean Ekoli-Yeden itself, however somebody typed it. */
const EKOLI_NAMES = ['ekoli', 'ekoli-yeden', 'ekoli yeden', 'yeden', 'ekori'];
const YAKURR_NAMES = ['yakurr', 'yakur'];
const CROSS_RIVER_NAMES = ['cross river', 'cross-river', 'crossriver'];

/**
 * Which tier a place belongs to.
 *
 * Deliberately forgiving about spelling: somebody typing "Ekori" on a phone
 * should land in the same tier as somebody typing "Ekoli-Yeden", and a match
 * that fails on a hyphen is a match that never happens.
 */
export function locationTier(place: {
  communityArea?: string | null;
  lga?: string | null;
  stateRegion?: string | null;
  country?: string | null;
  isRemote?: boolean;
}): LocationTier {
  const area = normalise(place.communityArea);
  const lga = normalise(place.lga);
  const state = normalise(place.stateRegion);
  const country = normalise(place.country);

  if (EKOLI_NAMES.some((name) => area.includes(name) || lga.includes(name))) return 'ekoli_yeden';
  if (YAKURR_NAMES.some((name) => lga.includes(name) || area.includes(name))) return 'yakurr';
  if (CROSS_RIVER_NAMES.some((name) => state.includes(name))) return 'cross_river';
  if (country.includes('nigeria')) return 'nigeria';
  if (place.isRemote) return 'remote';
  return 'international';
}

function normalise(value: string | null | undefined): string {
  return (value ?? '').trim().toLowerCase();
}

/** True where somebody's stated location is Ekoli-Yeden itself. */
export function isInEkoliYeden(place: {
  communityArea?: string | null;
  lga?: string | null;
}): boolean {
  return locationTier(place) === 'ekoli_yeden';
}

/** True where somebody is outside Nigeria. */
export function isDiaspora(country: string | null | undefined): boolean {
  const value = normalise(country);
  return value !== '' && !value.includes('nigeria');
}

/**
 * A URL-safe handle for a member's public page.
 *
 * Built from the display name, and separate from it: changing your name should
 * not break a link somebody has already shared.
 */
export function handleFrom(name: string, fallback: string): string {
  const base = name
    .normalize('NFKD')
    .replace(/[̀-ͯ]/g, '')
    .toLowerCase()
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 40)
    .replace(/-+$/g, '');
  return base === '' ? fallback : base;
}

/**
 * `Okoli-2026-0001` — the year somebody joined, and how many had joined before.
 *
 * ---------------------------------------------------------------------------
 * WHY IT IS COUNTED RATHER THAN RANDOM
 * ---------------------------------------------------------------------------
 *
 * It used to be `YK-` and six random characters. That is a fine identifier and
 * a poor membership number: it says nothing, sorts into no order, and two
 * people comparing theirs learn nothing about either.
 *
 * A counted number says when you joined and roughly where you stand in the
 * order of it, which is the thing a membership number is actually for in a
 * community that will still be adding people in fifty years.
 *
 * The count restarts each year, so 2027 begins again at 0001 and the year
 * carries the rest of the meaning. Four digits, and it widens rather than
 * wrapping if a year ever brings more than 9,999 people.
 *
 * ---------------------------------------------------------------------------
 * ON THE RACE
 * ---------------------------------------------------------------------------
 *
 * Reading the highest and adding one is not atomic, and two people registering
 * in the same second could compute the same number. `membership_number` is
 * UNIQUE, so the second write fails rather than issuing a duplicate — and the
 * caller retries. Losing a number to a collision is harmless; issuing the same
 * one to two people is not, and the constraint is what guarantees which of
 * those happens.
 */
export async function nextMembershipNumber(db: D1Database, when?: Date): Promise<string> {
  const year = (when ?? new Date()).getUTCFullYear();
  const prefix = `Okoli-${year}-`;

  const row = await db
    .prepare(
      `SELECT "membership_number" FROM "member_profiles"
       WHERE "membership_number" LIKE ?
       ORDER BY LENGTH("membership_number") DESC, "membership_number" DESC
       LIMIT 1`,
    )
    .bind(`${prefix}%`)
    .first<{ membership_number: string }>();

  const highest = row ? Number.parseInt(row.membership_number.slice(prefix.length), 10) : 0;
  const next = (Number.isFinite(highest) ? highest : 0) + 1;

  return `${prefix}${String(next).padStart(4, '0')}`;
}
