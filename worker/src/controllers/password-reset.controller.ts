import type { RequestContext } from '../types/api';
import type { UserRecord } from '../types/models';
import { PasswordResetService, type DeliveryOutcome } from '../services/password-reset.service';
import { AuthService } from '../services/auth.service';
import { AuditRepository } from '../repositories/audit.repository';
import { hashPassword } from '../utils/crypto';
import { assertUsablePassword } from '../utils/password-quality';
import { nowIso } from '../utils/id';
import { ForbiddenError } from '../utils/errors';
import { UserRepository } from '../repositories/user.repository';
import { NotificationRepository } from '../repositories/notification.repository';
import { BadRequestError, UnauthorizedError } from '../utils/errors';
import { hashIp } from '../utils/crypto';
import { readJsonBody, Validator } from '../utils/validation';
import { json, NO_STORE_HEADERS } from '../utils/responses';

/**
 * PASSWORD RESET ENDPOINTS
 *
 * Three surfaces, with different rules:
 *
 *   `/api/auth/forgot-password` — public, rate limited, and deliberately unable
 *   to tell you whether an account exists.
 *
 *   `/api/auth/reset-password` — public, consumes a single-use token.
 *
 *   `/api/admin/users/:id/reset-link` — an administrator generating a link on
 *   somebody's behalf. This one DOES return the link, because when no email or
 *   WhatsApp service is configured the administrator passing it on personally
 *   is the delivery mechanism.
 */

function clientIp(request: Request): string | null {
  return (
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null
  );
}

/**
 * `POST /api/auth/forgot-password`
 *
 * The response is identical whether or not the address is registered. An
 * archive of a community must not double as a way to find out who belongs to
 * it, and a "no such account" message would do exactly that.
 */
export async function forgotPassword(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const validated = new Validator(body).email('email', { required: true }).validated();
  const email = validated['email'] as string;

  const users = new UserRepository(context.env.DB);
  const user = await users.findByEmail(email);

  const sameAnswerEitherWay = {
    message:
      'If an account exists for that address, a reset link has been sent. Please check your ' +
      'email, and your WhatsApp if you gave us a number.',
  };

  if (!user || user.status !== 'active') {
    return json(sameAnswerEitherWay, { headers: NO_STORE_HEADERS });
  }

  const secret = context.env.JWT_SECRET;
  const issued = await new PasswordResetService(context.env).issue(user, {
    requestedBy: null,
    ipHash: secret ? await hashIp(clientIp(context.request), secret) : null,
    requestId: context.requestId,
  });

  // The administrators are told, so a failed delivery is not a dead end.
  await notifyAdministratorsOfReset(context, user, issued);

  return json(sameAnswerEitherWay, { headers: NO_STORE_HEADERS });
}

/**
 * Tells the Super Admins that somebody asked to reset their password.
 *
 * WHY THIS EXISTS.
 *
 * Email and WhatsApp both need configuration this platform may not have, and
 * both fail quietly for reasons nobody here controls — a wrong address, a full
 * mailbox, a number that changed. Without this, a member who cannot receive the
 * link has no way through at all, and nobody knows they are stuck.
 *
 * WHAT IT DOES AND DOES NOT CARRY.
 *
 * It says WHO asked and WHETHER IT REACHED THEM. It does not carry the link.
 *
 * That is a deliberate security decision and it should not be "improved" by
 * pasting the link in to save a click. A reset link is, for the hour it lives,
 * as good as the password. The service stores only a digest of it precisely so
 * that a copy of the database is not a pile of working credentials — and a
 * notification row holding the raw link would put one back, in plaintext,
 * readable by every administrator, and kept long after the token expired.
 *
 * The administrator is one press from a link instead: **Administration →
 * Users → Reset link** mints a fresh one and shows it once, and nothing keeps
 * it afterwards. That is the same outcome for the person who is locked out,
 * without leaving a credential lying in a table.
 *
 * A temporary password is NOT issued here either. Issuing one replaces the
 * account's password and signs out every session, so doing it automatically
 * would let anybody lock any member out of their account by typing that
 * member's address into a public form.
 */
async function notifyAdministratorsOfReset(
  context: RequestContext,
  user: UserRecord,
  issued: { delivery: DeliveryOutcome },
): Promise<void> {
  const result = await context.env.DB.prepare(
    `SELECT DISTINCT ur."user_id" FROM "user_roles" ur
     INNER JOIN "roles" r ON r."id" = ur."role_id"
     WHERE r."slug" IN ('super_admin', 'deputy_super_admin')`,
  ).all<{ user_id: string }>();

  const administrators = (result.results ?? [])
    .map((row) => row.user_id)
    // Never to the person resetting their own password: they have the link, and
    // an administrator resetting their own account does not need to tell
    // themselves about it.
    .filter((id) => id !== user.id);

  if (administrators.length === 0) return;

  const who = user.display_name ? `${user.display_name} (${user.email})` : user.email;

  const body = issued.delivery.delivered
    ? `Sent by ${issued.delivery.channel} to ${issued.delivery.destination ?? 'their address'}. `
      + 'Nothing to do unless they say it never arrived.'
    : `It could not be sent${issued.delivery.reason ? ` — ${issued.delivery.reason}` : ''}, `
      + 'so they have not received anything. Open Administration → Users and press "Reset '
      + 'link" on their row to get a link you can pass on, or "Temporary password" if they '
      + 'cannot open a link at all.';

  await new NotificationRepository(context.env.DB).notifyMany(administrators, {
    kind: 'membership',
    title: `${who} asked to reset their password`,
    body,
    linkPath: '/admin/users',
    resourceType: 'user',
    resourceId: user.id,
  });
}

/** `GET /api/auth/reset-password/:token` — is this link still usable? */
export async function checkResetToken(context: RequestContext): Promise<Response> {
  const token = context.params['token'] ?? '';
  const valid = await new PasswordResetService(context.env).check(token);

  return json(
    {
      valid,
      message: valid
        ? 'This link is valid. Choose a new password.'
        : 'This link has expired or has already been used. Please request a new one.',
    },
    { headers: NO_STORE_HEADERS },
  );
}

/** `POST /api/auth/reset-password` — redeem the token and set the password. */
export async function resetPassword(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('token', { required: true, min: 20, max: 400, label: 'Reset token' })
    .string('password', { required: true, min: 6, max: 200, label: 'Password' })
    .validated();

  assertUsablePassword(validated['password'] as string);

  const secret = context.env.JWT_SECRET;
  const ipHash = secret ? await hashIp(clientIp(context.request), secret) : null;

  const account = await new PasswordResetService(context.env).redeem(
    validated['token'] as string,
    validated['password'] as string,
    { requestId: context.requestId, ipHash },
  );

  // Signed in on the spot. Every other session was ended by the redemption —
  // which is the point, since a reset usually means somebody else may have had
  // access — and this is the one new session, belonging to the person who just
  // proved they hold the reset token and chose the password.
  const tokens = await new AuthService(context.env).issueTokens(account.id, account.email, {
    userAgent: context.request.headers.get('user-agent'),
    ipHash,
  });

  return json(
    {
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      message:
        'Your password has been changed and you are signed in. Every other session has been '
        + 'ended, so anybody else who was using this account has been signed out.',
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `POST /api/admin/users/:id/reset-link`
 *
 * Generates a reset link for another account. The link is returned to the
 * administrator so they can pass it on — which is the whole delivery mechanism
 * until an email or WhatsApp service is configured, and remains a useful
 * fallback afterwards for somebody whose email has stopped working.
 *
 * This is preferable to an administrator choosing a password on somebody's
 * behalf, because it means no administrator ever learns another person's
 * password.
 */
export async function createResetLink(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const userId = context.params['id'] ?? '';
  const users = new UserRepository(context.env.DB);
  const user = await users.findById(userId);
  if (!user) throw new BadRequestError('That user was not found.');

  const body = await readJsonBody(context.request).catch(() => ({}) as Record<string, unknown>);
  const preferred = body['channel'];
  const channel =
    preferred === 'whatsapp' || preferred === 'email' ? preferred : undefined;

  const secret = context.env.JWT_SECRET;
  const issued = await new PasswordResetService(context.env).issue(user, {
    requestedBy: actor.id,
    ipHash: secret ? await hashIp(clientIp(context.request), secret) : null,
    requestId: context.requestId,
    preferChannel: channel,
  });

  return json(
    {
      userId: user.id,
      email: user.email,
      displayName: user.display_name,
      resetUrl: issued.resetUrl,
      expiresAt: issued.expiresAt,
      delivery: issued.delivery,
      guidance: issued.delivery.delivered
        ? `The link was sent by ${issued.delivery.channel} to ${issued.delivery.destination}.`
        : 'The link was not sent automatically. Copy it and give it to the person directly — ' +
          'over WhatsApp, in person, or however you normally reach them. It works once, then expires.',
    },
    { headers: NO_STORE_HEADERS },
  );
}


/**
 * `POST /api/admin/users/:id/temporary-password`
 *
 * Sets a temporary password an administrator can read out, which the account
 * must replace before it can do anything else.
 *
 * WHY THIS EXISTS WHEN RESET LINKS ALREADY DO.
 *
 * A link is the better mechanism and stays the default: no administrator ever
 * learns anybody's password. It also assumes the person can receive and open a
 * link, which is not always true — an elder on a borrowed phone, somebody whose
 * email stopped working years ago, somebody standing in front of an
 * administrator right now with a phone that cannot open the message.
 *
 * WHAT KEEPS IT FROM BECOMING A SHARED PASSWORD.
 *
 * `must_change_password` is set, and the sign-in path refuses to issue an
 * ordinary session while it stands. The temporary password buys exactly one
 * thing: the right to choose a real one. An administrator who knows it can
 * therefore reach the change-password screen and nothing else, and the moment
 * the member sets their own, the administrator's knowledge is worthless.
 */
export async function issueTemporaryPassword(context: RequestContext): Promise<Response> {
  const actor = context.user;
  if (!actor) throw new UnauthorizedError('Please sign in to continue.');

  const userId = context.params['id'] ?? '';
  const users = new UserRepository(context.env.DB);
  const user = await users.findById(userId);
  if (!user) throw new BadRequestError('That user was not found.');

  // Not for another administrator's account. Somebody who can hand themselves a
  // temporary password for a Super Admin has, in effect, that Super Admin's
  // authority — the whole permission model would rest on nobody noticing.
  const theirRoles = await users.rolesForUser(user.id);
  if (user.id !== actor.id && theirRoles.some((role) => role.slug === 'super_admin')) {
    throw new ForbiddenError(
      'A Super Admin account cannot be given a temporary password this way. Use a reset link, '
        + 'which only its holder can open.',
    );
  }

  // How long it lives, from the security settings rather than from a constant
  // in here — the right value depends on how this community actually works.
  const ttlRow = await context.env.DB
    .prepare('SELECT "value" FROM "site_settings" WHERE "key" = ? LIMIT 1')
    .bind('temp_password_ttl_hours')
    .first<{ value: string | null }>();
  const parsedTtl = Number(ttlRow?.value ?? 72);
  const ttlHours = Number.isFinite(parsedTtl) && parsedTtl > 0 ? parsedTtl : 72;

  const temporary = generateTemporaryPassword();
  const { hash, salt } = await hashPassword(temporary);
  const issuedAt = nowIso();

  await users.update(user.id, {
    password_hash: hash,
    password_salt: salt,
    must_change_password: 1,
    temp_password_issued_by: actor.id,
    // Stamped, and ENFORCED at sign-in against `temp_password_ttl_hours`.
    // Without the stamp being checked, a password read down a phone line works
    // for ever if the member never gets round to signing in — and the word
    // "temporary" in its name would be decoration.
    temp_password_issued_at: issuedAt,
  });

  // Every existing session ends. If the reason for this is that somebody else
  // had access, leaving their session alive would defeat the whole exercise.
  await users.revokeAllSessionsForUser(user.id);

  await new AuditRepository(context.env.DB).record({
    actorId: actor.id,
    actorEmail: actor.email,
    action: 'auth.temporary_password.issued',
    resourceType: 'user',
    resourceId: user.id,
    changes: { for: user.email, sessionsRevoked: true },
    requestId: context.requestId,
  });

  return json(
    {
      userId: user.id,
      email: user.email,
      displayName: user.display_name,
      temporaryPassword: temporary,
      expiresInHours: ttlHours,
      guidance:
        `Read this out to them, or write it down and hand it over. It stops working in ${ttlHours} `
        + 'hours, and it works once even before that: the moment they sign in they must choose '
        + 'their own password. Every other session on the account has been signed out.',
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * A temporary password somebody can read down a phone line.
 *
 * Three short words and a number rather than a random string. It has to survive
 * being spoken aloud, possibly in a second language, possibly to somebody
 * writing it on paper — and `xK7#mQ2$vB9!` does not. Length carries the
 * strength instead of punctuation, and it lives for hours rather than for ever.
 *
 * Characters that look alike when handwritten are absent from the word list on
 * purpose, and the digits avoid 0 and 1.
 */
function generateTemporaryPassword(): string {
  const words = [
    'harvest', 'river', 'palm', 'thunder', 'market', 'evening', 'yam', 'drum',
    'village', 'sunrise', 'basket', 'cocoa', 'forest', 'season', 'bridge', 'kernel',
    'compound', 'festival', 'elder', 'rainfall', 'stream', 'hillside', 'garden', 'lantern',
  ];

  const bytes = new Uint8Array(4);
  crypto.getRandomValues(bytes);

  const chosen = Array.from(bytes.slice(0, 3), (byte) => words[byte % words.length]);
  const number = 234 + (bytes[3] ?? 0);

  return `${chosen.join('-')}-${number}`;
}
