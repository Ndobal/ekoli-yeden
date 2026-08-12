import type { RequestContext } from '../types/api';
import { PasswordResetService } from '../services/password-reset.service';
import { UserRepository } from '../repositories/user.repository';
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
  await new PasswordResetService(context.env).issue(user, {
    requestedBy: null,
    ipHash: secret ? await hashIp(clientIp(context.request), secret) : null,
    requestId: context.requestId,
  });

  return json(sameAnswerEitherWay, { headers: NO_STORE_HEADERS });
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
    .string('password', { required: true, min: 12, max: 200, label: 'Password' })
    .validated();

  const secret = context.env.JWT_SECRET;
  await new PasswordResetService(context.env).redeem(
    validated['token'] as string,
    validated['password'] as string,
    {
      requestId: context.requestId,
      ipHash: secret ? await hashIp(clientIp(context.request), secret) : null,
    },
  );

  return json(
    {
      message:
        'Your password has been changed and you have been signed out everywhere. Please sign in ' +
        'with your new password.',
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
