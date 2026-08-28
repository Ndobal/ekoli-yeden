import { BadRequestError } from './errors';

/**
 * WHETHER A PASSWORD IS ONE SOMEBODY WOULD GUESS FIRST.
 *
 * ---------------------------------------------------------------------------
 * WHY THIS EXISTS, AND WHY IT MATTERS MORE THAN LENGTH DOES
 * ---------------------------------------------------------------------------
 *
 * The minimum length here is six characters. That is short — deliberately so,
 * because this community is reached on shared phones and by people who will
 * write their password on paper, and a twelve-character rule produces
 * `Password123!` on a sticky note far more often than it produces security.
 *
 * But a short minimum is only safe if the obvious answers are refused. Nearly
 * every account actually broken into is broken into with a list of a few
 * hundred strings — `123456`, `password`, `qwerty`, the person's own name —
 * not by exhausting the keyspace. Length defends against the second attack.
 * This file defends against the first, which is the one that happens.
 *
 * So the rules below are not a strength meter and deliberately demand no
 * capital letters, no digits and no punctuation. Composition rules of that kind
 * are known to make passwords more predictable rather than less: told to add a
 * number, people add `1` at the end. What is refused here is only what is
 * genuinely guessable:
 *
 *   - the passwords that appear at the top of every breach list
 *   - one character repeated, and simple runs off the keyboard
 *   - the person's own name, handle or email
 *
 * Everything else a member chooses is accepted, including a short one they can
 * actually remember. Rate limiting on sign-in, PBKDF2 at 100,000 iterations,
 * and sessions that can be revoked are what carry the rest of the load.
 */

/**
 * The strings that get tried first.
 *
 * Kept deliberately short and specific rather than importing a list of ten
 * thousand: this runs on every password change, and the long tail of a breach
 * list adds almost nothing once the head is refused.
 *
 * Nigerian and community-specific guesses are included alongside the global
 * ones, because "ekoli", "yakurr" and "naija" are exactly what somebody sets on
 * a site called this.
 */
const COMMON = new Set<string>([
  '123456', '1234567', '12345678', '123456789', '1234567890',
  'password', 'password1', 'passw0rd', 'p@ssword', 'p@ssw0rd',
  'qwerty', 'qwerty123', 'qwertyuiop', 'asdfgh', 'asdfghjkl', 'zxcvbn', 'zxcvbnm',
  'abc123', 'abcdef', 'abcd1234', '111111', '000000', '654321', '121212',
  'iloveyou', 'letmein', 'welcome', 'monkey', 'dragon', 'sunshine', 'princess',
  'football', 'baseball', 'trustno1', 'admin', 'admin123', 'administrator',
  'root', 'toor', 'guest', 'test123', 'changeme', 'secret', 'default',
  'nigeria', 'naija', 'lagos', 'chelsea', 'arsenal', 'manchester', 'jesus',
  'godislove', 'blessing', 'ekoli', 'ekoliyeden', 'yakurr', 'yakoli', 'ekori',
]);

/**
 * Rejects a password that is guessable, in words the person can act on.
 *
 * Throws `BadRequestError` with a message written for the person choosing,
 * never a rule list. "Please choose something less common" tells them what to
 * do; "must contain one uppercase, one digit and one symbol" tells them how to
 * produce `Passw0rd!`.
 *
 * `identity` is the account's own email, name and handle. A password that is
 * the person's own name is the second thing anybody tries after `123456`.
 */
export function assertUsablePassword(
  password: string,
  identity: { email?: string | null; displayName?: string | null; handle?: string | null } = {},
): void {
  const value = password.trim();

  if (value.length < 6) {
    throw new BadRequestError('Please use at least six characters.');
  }

  const normalised = value.toLowerCase();

  if (COMMON.has(normalised)) {
    throw new BadRequestError(
      'That is one of the most commonly used passwords in the world, so it is one of the first '
        + 'anybody tries. Please choose something else — it can still be short.',
    );
  }

  // One character over and over: "aaaaaa", "111111".
  if (/^(.)\1+$/.test(value)) {
    throw new BadRequestError(
      'That is the same character repeated. Please choose something else.',
    );
  }

  // A run off the keyboard or up the digits, forwards or backwards.
  if (isSequential(normalised)) {
    throw new BadRequestError(
      'That is a straight run of letters or numbers, which is among the first things guessed. '
        + 'Please choose something else.',
    );
  }

  // Their own name, handle, or the part of their email before the @.
  const ownWords = [
    identity.displayName,
    identity.handle,
    identity.email?.split('@')[0],
  ]
    .filter((word): word is string => typeof word === 'string' && word.trim().length >= 3)
    .map((word) => word.trim().toLowerCase());

  for (const word of ownWords) {
    if (normalised === word || normalised.includes(word) || word.includes(normalised)) {
      throw new BadRequestError(
        'That is too close to your own name or email address, which is the first thing anybody '
          + 'guesses. Please choose something else.',
      );
    }
  }
}

/**
 * A straight run in either direction: `123456`, `abcdef`, `fedcba`, `654321`.
 *
 * Checked over the whole string rather than for a run inside it — a password
 * that merely CONTAINS "123" is fine, one that IS "123456" is not.
 */
function isSequential(value: string): boolean {
  if (value.length < 4) return false;

  let ascending = true;
  let descending = true;

  for (let index = 1; index < value.length; index += 1) {
    const step = value.charCodeAt(index) - value.charCodeAt(index - 1);
    if (step !== 1) ascending = false;
    if (step !== -1) descending = false;
  }

  return ascending || descending;
}
