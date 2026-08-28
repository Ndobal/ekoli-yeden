/**
 * KINSHIP — how the community says who belongs to whom.
 *
 * The vocabulary, the inverses, and the rules about what a relationship means.
 * Kept apart from the repository because these are decisions rather than data
 * access, and because the death-confirmation safeguard depends on getting the
 * definition of "already family" exactly right.
 */

export const RELATIONSHIP_TYPES = [
  'spouse', 'husband', 'wife',
  'father', 'mother', 'parent',
  'son', 'daughter', 'child',
  'brother', 'sister', 'sibling',
  'grandfather', 'grandmother', 'grandparent',
  'grandson', 'granddaughter', 'grandchild',
  'uncle', 'aunt', 'nephew', 'niece', 'cousin',
  'father_in_law', 'mother_in_law', 'son_in_law', 'daughter_in_law',
  'brother_in_law', 'sister_in_law',
  'stepfather', 'stepmother', 'stepson', 'stepdaughter',
  'stepbrother', 'stepsister',
  'guardian', 'ward', 'godparent', 'godchild',
  'kin', 'other',
] as const;

export type RelationshipType = (typeof RELATIONSHIP_TYPES)[number];

export const RELATIONSHIP_LABELS: Record<string, string> = {
  spouse: 'Spouse', husband: 'Husband', wife: 'Wife',
  father: 'Father', mother: 'Mother', parent: 'Parent',
  son: 'Son', daughter: 'Daughter', child: 'Child',
  brother: 'Brother', sister: 'Sister', sibling: 'Sibling',
  grandfather: 'Grandfather', grandmother: 'Grandmother', grandparent: 'Grandparent',
  grandson: 'Grandson', granddaughter: 'Granddaughter', grandchild: 'Grandchild',
  uncle: 'Uncle', aunt: 'Aunt', nephew: 'Nephew', niece: 'Niece', cousin: 'Cousin',
  father_in_law: 'Father-in-law', mother_in_law: 'Mother-in-law',
  son_in_law: 'Son-in-law', daughter_in_law: 'Daughter-in-law',
  brother_in_law: 'Brother-in-law', sister_in_law: 'Sister-in-law',
  stepfather: 'Stepfather', stepmother: 'Stepmother',
  stepson: 'Stepson', stepdaughter: 'Stepdaughter',
  stepbrother: 'Stepbrother', stepsister: 'Stepsister',
  guardian: 'Guardian', ward: 'Ward',
  godparent: 'Godparent', godchild: 'Godchild',
  kin: 'Kin', other: 'Related',
};

/**
 * How the relationships are grouped in the picker.
 *
 * Forty options in one flat list is a list nobody reads to the end of.
 */
export const RELATIONSHIP_GROUPS: { label: string; types: string[] }[] = [
  { label: 'Marriage', types: ['husband', 'wife', 'spouse'] },
  { label: 'Parents and children', types: ['father', 'mother', 'parent', 'son', 'daughter', 'child'] },
  { label: 'Brothers and sisters', types: ['brother', 'sister', 'sibling'] },
  { label: 'Grandparents and grandchildren', types: ['grandfather', 'grandmother', 'grandparent', 'grandson', 'granddaughter', 'grandchild'] },
  { label: 'Wider family', types: ['uncle', 'aunt', 'nephew', 'niece', 'cousin', 'kin'] },
  { label: 'In-laws', types: ['father_in_law', 'mother_in_law', 'son_in_law', 'daughter_in_law', 'brother_in_law', 'sister_in_law'] },
  { label: 'Step family', types: ['stepfather', 'stepmother', 'stepson', 'stepdaughter', 'stepbrother', 'stepsister'] },
  { label: 'Guardianship', types: ['guardian', 'ward', 'godparent', 'godchild'] },
  { label: 'Something else', types: ['other'] },
];

/**
 * What the other person becomes, when somebody says "you are my father".
 *
 * Where the answer depends on the accepter's own sex — a father's child is a
 * son or a daughter — this returns the CHOICES rather than picking one. The
 * accepter says which they are; the platform does not guess, and does not ask
 * anybody to record their sex just so it can.
 */
export function inverseOptionsFor(type: string): string[] {
  const exact: Record<string, string[]> = {
    // Symmetrical.
    spouse: ['spouse'],
    husband: ['wife', 'spouse'],
    wife: ['husband', 'spouse'],
    cousin: ['cousin'],
    sibling: ['sibling', 'brother', 'sister'],
    brother: ['brother', 'sister', 'sibling'],
    sister: ['brother', 'sister', 'sibling'],
    stepbrother: ['stepbrother', 'stepsister'],
    stepsister: ['stepbrother', 'stepsister'],
    brother_in_law: ['brother_in_law', 'sister_in_law'],
    sister_in_law: ['brother_in_law', 'sister_in_law'],
    kin: ['kin'],
    other: ['other'],

    // Generational, so the inverse flips.
    father: ['son', 'daughter', 'child'],
    mother: ['son', 'daughter', 'child'],
    parent: ['son', 'daughter', 'child'],
    son: ['father', 'mother', 'parent'],
    daughter: ['father', 'mother', 'parent'],
    child: ['father', 'mother', 'parent'],

    grandfather: ['grandson', 'granddaughter', 'grandchild'],
    grandmother: ['grandson', 'granddaughter', 'grandchild'],
    grandparent: ['grandson', 'granddaughter', 'grandchild'],
    grandson: ['grandfather', 'grandmother', 'grandparent'],
    granddaughter: ['grandfather', 'grandmother', 'grandparent'],
    grandchild: ['grandfather', 'grandmother', 'grandparent'],

    uncle: ['nephew', 'niece'],
    aunt: ['nephew', 'niece'],
    nephew: ['uncle', 'aunt'],
    niece: ['uncle', 'aunt'],

    father_in_law: ['son_in_law', 'daughter_in_law'],
    mother_in_law: ['son_in_law', 'daughter_in_law'],
    son_in_law: ['father_in_law', 'mother_in_law'],
    daughter_in_law: ['father_in_law', 'mother_in_law'],

    stepfather: ['stepson', 'stepdaughter'],
    stepmother: ['stepson', 'stepdaughter'],
    stepson: ['stepfather', 'stepmother'],
    stepdaughter: ['stepfather', 'stepmother'],

    guardian: ['ward'],
    ward: ['guardian'],
    godparent: ['godchild'],
    godchild: ['godparent'],
  };

  return exact[type] ?? ['kin'];
}

/**
 * Relationships close enough to confirm a death.
 *
 * The safeguard rests entirely on this list, so it is deliberately narrow:
 * immediate family and the people who would actually know. A cousin twice
 * removed who accepted a connection request three years ago should not be able
 * to still somebody's account on their own.
 *
 * A Preservation Team member can confirm regardless — that is recorded as an
 * official confirmation rather than a family one, and the two are told apart.
 */
const CLOSE_ENOUGH_TO_CONFIRM_DEATH = new Set<string>([
  'spouse', 'husband', 'wife',
  'father', 'mother', 'parent',
  'son', 'daughter', 'child',
  'brother', 'sister', 'sibling',
  'grandfather', 'grandmother', 'grandparent',
  'grandson', 'granddaughter', 'grandchild',
  'uncle', 'aunt', 'nephew', 'niece',
  'guardian', 'ward',
]);

export function canConfirmDeath(relationshipType: string): boolean {
  return CLOSE_ENOUGH_TO_CONFIRM_DEATH.has(relationshipType);
}

/**
 * A phone number reduced to something two people can match on.
 *
 * `+234 803 123 4567`, `0803 123 4567` and `234-803-123-4567` are the same
 * person. A connection that fails because somebody typed a space is a
 * connection that never happens.
 *
 * The leading zero of a national number is dropped once a country code is
 * present, because `+2340803…` is nobody.
 */
export function normalisePhone(raw: string | null | undefined, defaultCountry = '234'): string | null {
  if (!raw) return null;

  const trimmed = raw.trim();
  const hasPlus = trimmed.startsWith('+');
  const digits = trimmed.replace(/\D/g, '');
  if (digits.length < 7) return null;

  if (hasPlus || digits.startsWith(defaultCountry)) {
    // Already international. Strip a national trunk zero sitting after the
    // country code, which people type out of habit.
    const withoutCountry = digits.startsWith(defaultCountry)
      ? digits.slice(defaultCountry.length)
      : digits;
    const country = digits.startsWith(defaultCountry) ? defaultCountry : '';
    return `${country}${withoutCountry.replace(/^0+/, '')}` || null;
  }

  // A national number: drop the trunk zero and prefix the country.
  return `${defaultCountry}${digits.replace(/^0+/, '')}`;
}

/** How a phone number is shown back to its owner. Never to anybody else. */
export function formatPhone(normalised: string | null): string | null {
  if (!normalised) return null;
  return `+${normalised}`;
}

// ---------------------------------------------------------------------------
// Birthdays
// ---------------------------------------------------------------------------

/**
 * Splits a date of birth into the parts the platform actually uses.
 *
 * The day and month are what the community sees. The year is kept private:
 * somebody can be wished a happy birthday without their age being published,
 * and the year is only ever used for age-grade brackets.
 */
export function splitBirthDate(
  value: string | null | undefined,
): { date: string; day: number; month: number; year: number } | null {
  if (!value) return null;

  const match = /^(\d{4})-(\d{2})-(\d{2})/.exec(value.trim());
  if (!match) return null;

  const year = Number(match[1]);
  const month = Number(match[2]);
  const day = Number(match[3]);

  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  if (year < 1900 || year > new Date().getUTCFullYear()) return null;

  // Rejects the 31st of a 30-day month and the 30th of February. A birthday
  // that never arrives is worse than no birthday recorded.
  const probe = new Date(Date.UTC(year, month - 1, day));
  if (probe.getUTCMonth() !== month - 1 || probe.getUTCDate() !== day) return null;

  return { date: `${match[1]}-${match[2]}-${match[3]}`, day, month, year };
}

/**
 * Today, in the community's own day rather than the server's.
 *
 * Birthdays are a local matter: somebody in Ekoli-Yeden should be wished well
 * on their day there, not on UTC's. Cross River is UTC+1 all year, so this is
 * a fixed offset rather than a timezone database.
 */
export function communityToday(now: Date = new Date()): { day: number; month: number; year: number } {
  const local = new Date(now.getTime() + 60 * 60 * 1000);
  return {
    day: local.getUTCDate(),
    month: local.getUTCMonth() + 1,
    year: local.getUTCFullYear(),
  };
}

/**
 * The 29th of February.
 *
 * Somebody born on a leap day has a birthday in three years out of four. The
 * community should still wish them well, so in a non-leap year their day is
 * counted as the 28th — which is the convention most people use for themselves.
 */
export function birthdayFallsToday(
  birthDay: number,
  birthMonth: number,
  today: { day: number; month: number; year: number },
): boolean {
  if (birthMonth === today.month && birthDay === today.day) return true;

  const isLeapDay = birthMonth === 2 && birthDay === 29;
  if (!isLeapDay) return false;

  const isLeapYear =
    (today.year % 4 === 0 && today.year % 100 !== 0) || today.year % 400 === 0;
  return !isLeapYear && today.month === 2 && today.day === 28;
}

/** Age in whole years, computed but rarely shown. */
export function ageOn(birthYear: number, birthMonth: number, birthDay: number, on: Date = new Date()): number {
  const year = on.getUTCFullYear();
  const month = on.getUTCMonth() + 1;
  const day = on.getUTCDate();

  let age = year - birthYear;
  if (month < birthMonth || (month === birthMonth && day < birthDay)) age -= 1;
  return age;
}
