/**
 * Identifier helpers.
 *
 * Every table uses a TEXT primary key so that ids can be generated on the
 * Worker, remain stable across environments and never leak row counts.
 */

/** A random, URL-safe, collision-resistant id (UUID v4 without dashes). */
export function newId(): string {
  return crypto.randomUUID().replace(/-/g, '');
}

/** A prefixed id, e.g. `usr_3f2a…`, which makes logs and audit trails readable. */
export function prefixedId(prefix: string): string {
  return `${prefix}_${newId()}`;
}

/**
 * A short human-quotable reference for community submissions, e.g. `EY-7K3QD2`.
 * Contributors quote this when they follow up with the Preservation Team.
 */
export function submissionReference(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no I/O/0/1
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  let code = '';
  for (const byte of bytes) code += alphabet[byte % alphabet.length];
  return `EY-${code}`;
}

/** Current timestamp in the ISO-8601 form stored in every `*_at` column. */
export function nowIso(): string {
  return new Date().toISOString();
}
