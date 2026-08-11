/**
 * Slug helpers.
 *
 * Slugs form the public URLs of the archive (`/history/:slug`,
 * `/leboku/2026`), so they must be stable, lowercase and free of characters
 * that would need escaping.
 */

/** Unicode combining marks, stripped so accented letters degrade to their base. */
const COMBINING_MARKS = /[̀-ͯ]/g;
const APOSTROPHES = /['‘’]/g;

export function slugify(input: string): string {
  return input
    .normalize('NFKD')
    .replace(COMBINING_MARKS, '')
    .toLowerCase()
    .replace(APOSTROPHES, '')
    .replace(/[^a-z0-9]+/g, '-')
    .replace(/^-+|-+$/g, '')
    .slice(0, 120)
    .replace(/-+$/g, '');
}

export function isValidSlug(value: string): boolean {
  return /^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(value) && value.length <= 120;
}

/** Festival slugs are `<name>-<year>`, e.g. `leboku-2026`. */
export function festivalSlug(name: string, year: number): string {
  return `${slugify(name)}-${year}`;
}
