import type { RequestContext } from '../types/api';
import { AuthService } from '../services/auth.service';
import { MembershipService } from '../services/membership.service';
import { PasswordResetService } from '../services/password-reset.service';
import { UserRepository } from '../repositories/user.repository';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { UnauthorizedError } from '../utils/errors';
import { assertUsablePassword } from '../utils/password-quality';
import { hashIp, requireSecret } from '../utils/crypto';
import { readJsonBody, Validator } from '../utils/validation';
import { NO_STORE_HEADERS, json } from '../utils/responses';
import { PRESERVATION_TEAM } from '../services/preservation-team.service';

/** Registration and sign-in for community members and administrators. */

function clientIp(request: Request): string | null {
  return (
    request.headers.get('cf-connecting-ip') ??
    request.headers.get('x-forwarded-for')?.split(',')[0]?.trim() ??
    null
  );
}

export async function register(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .email('email', { required: true })
    .string('password', { required: true, min: 6, max: 200, label: 'Password' })
    .string('display_name', { required: true, min: 2, max: 120, label: 'Name' })
    .validated();

  // Six characters is the minimum, which is short on purpose — and a short
  // minimum is only safe if the guessable answers are refused. See
  // `password-quality.ts`.
  assertUsablePassword(validated['password'] as string, {
    email: validated['email'] as string,
    displayName: validated['display_name'] as string,
  });

  const auth = new AuthService(context.env);
  const userId = await auth.register({
    email: validated['email'] as string,
    password: validated['password'] as string,
    displayName: validated['display_name'] as string,
  });

  // Registering is joining. Every registered person is a member of
  // Ekoli-Yeden and a contributor to its archive — there is no separate
  // contributor account, and there was never a good reason for one: the old
  // `contributor` role held no permissions and could not contribute, because
  // contributing requires a member profile.
  await new MembershipService(context.env).ensureMembership(
    {
      id: userId,
      email: validated['email'] as string,
      displayName: validated['display_name'] as string,
      status: 'active',
      roles: [],
      permissions: new Set<string>(),
    },
    { requestId: context.requestId },
  );

  const audit = new AuditRepository(context.env.DB);
  await audit.record({
    actorId: userId,
    actorEmail: validated['email'] as string,
    action: AUDIT_ACTIONS.USER_CREATED,
    resourceType: 'user',
    resourceId: userId,
    changes: { via: 'self-registration', role: 'okoli_member' },
    requestId: context.requestId,
  });

  // SIGNED IN IMMEDIATELY, RATHER THAN SENT BACK TO A SIGN-IN FORM.
  //
  // Somebody who has just chosen a password and typed it correctly has proved
  // exactly what the sign-in form would ask them to prove, thirty seconds
  // later, from memory. Making them do it again is a step that only loses
  // people — and the next thing they need is their dashboard, where the
  // membership is actually completed.
  const secret = requireSecret(context.env.JWT_SECRET, 'JWT_SECRET');
  const ipHash = await hashIp(clientIp(context.request), secret);
  const tokens = await auth.issueTokens(userId, validated['email'] as string, {
    userAgent: context.request.headers.get('user-agent'),
    ipHash,
  });

  await audit.record({
    actorId: userId,
    actorEmail: validated['email'] as string,
    action: AUDIT_ACTIONS.LOGIN_SUCCEEDED,
    resourceType: 'user',
    resourceId: userId,
    ipHash,
    userAgent: context.request.headers.get('user-agent'),
    changes: { via: 'registration' },
    requestId: context.requestId,
  });

  return json(
    {
      id: userId,
      accessToken: tokens.accessToken,
      refreshToken: tokens.refreshToken,
      expiresIn: tokens.expiresIn,
      user: {
        id: userId,
        email: validated['email'] as string,
        displayName: validated['display_name'] as string,
        status: 'active',
        roles: ['okoli_member'],
        permissions: [],
        isMember: false,
      },
      message:
        'Welcome to Ekoli-Yeden. Your account and your membership are ready — fill in your '
        + 'profile so the community can find you, and send in whatever you have for the archive.',
    },
    { status: 201, headers: NO_STORE_HEADERS },
  );
}

export async function login(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .email('email', { required: true })
    .string('password', { required: true, min: 1, max: 200, label: 'Password' })
    .validated();

  const email = validated['email'] as string;
  const auth = new AuthService(context.env);
  const audit = new AuditRepository(context.env.DB);
  const secret = requireSecret(context.env.JWT_SECRET, 'JWT_SECRET');
  const ipHash = await hashIp(clientIp(context.request), secret);

  try {
    const user = await auth.authenticate(email, validated['password'] as string);

    // A TEMPORARY PASSWORD BUYS EXACTLY ONE THING: THE RIGHT TO CHOOSE A REAL
    // ONE.
    //
    // Without this, an administrator who read a temporary password down the
    // phone would hold a working credential for that account indefinitely, and
    // the "temporary" in its name would be decoration. So no session is issued
    // at all — instead the account is handed a single-use reset token and sent
    // to choose a password, and redeeming that signs them in properly.
    const record = await new UserRepository(context.env.DB).findById(user.id);
    if (record?.must_change_password === 1) {
      // AND IT STOPS WORKING.
      //
      // A temporary password is read out over a phone line, written on paper,
      // and forwarded in a chat. Without an expiry, one issued in March is a
      // working credential in December for anybody who kept the note — and the
      // account holder, who never signed in, has no idea it exists.
      //
      // The window comes from `temp_password_ttl_hours` in the security
      // settings rather than a constant here, because the right value depends
      // on how quickly this community actually reaches each other.
      if (await temporaryPasswordExpired(context, record.temp_password_issued_at)) {
        await audit.record({
          actorId: user.id,
          actorEmail: user.email,
          action: 'auth.temporary_password.expired',
          resourceType: 'user',
          resourceId: user.id,
          ipHash,
          requestId: context.requestId,
        });

        throw new UnauthorizedError(
          'That temporary password has expired. Ask an administrator for a new one, or use '
            + '"Forgot password" to have a link sent to you.',
        );
      }

      const handover = await new PasswordResetService(context.env).issue(record, {
        requestedBy: user.id,
        ipHash,
        requestId: context.requestId,
        // Not sent anywhere. They are already here, holding the temporary
        // password; posting a link to an address they may not reach would only
        // put them back where they started.
        preferChannel: undefined,
      });

      await audit.record({
        actorId: user.id,
        actorEmail: user.email,
        action: 'auth.temporary_password.used',
        resourceType: 'user',
        resourceId: user.id,
        ipHash,
        requestId: context.requestId,
      });

      return json(
        {
          mustChangePassword: true,
          resetToken: handover.token,
          expiresAt: handover.expiresAt,
          message:
            'This is a temporary password. Please choose your own now — it takes a moment, and '
            + 'you will be signed in straight afterwards.',
        },
        { status: 200, headers: NO_STORE_HEADERS },
      );
    }

    const tokens = await auth.issueTokens(user.id, user.email, {
      userAgent: context.request.headers.get('user-agent'),
      ipHash,
    });

    await audit.record({
      actorId: user.id,
      actorEmail: user.email,
      action: AUDIT_ACTIONS.LOGIN_SUCCEEDED,
      resourceType: 'user',
      resourceId: user.id,
      ipHash,
      userAgent: context.request.headers.get('user-agent'),
      requestId: context.requestId,
    });

    return json(
      {
        accessToken: tokens.accessToken,
        refreshToken: tokens.refreshToken,
        expiresIn: tokens.expiresIn,
        user: serializeUser(user),
      },
      { headers: NO_STORE_HEADERS },
    );
  } catch (error) {
    // Failed attempts are logged so the Technology Team can spot an attack,
    // but the attempted password is of course never recorded.
    await audit.record({
      actorId: null,
      actorEmail: email,
      action: AUDIT_ACTIONS.LOGIN_FAILED,
      resourceType: 'user',
      resourceId: null,
      ipHash,
      userAgent: context.request.headers.get('user-agent'),
      requestId: context.requestId,
    });
    throw error;
  }
}

export async function refresh(context: RequestContext): Promise<Response> {
  const body = await readJsonBody(context.request);
  const validated = new Validator(body)
    .string('refreshToken', { required: true, min: 20, max: 4000, label: 'Refresh token' })
    .validated();

  const auth = new AuthService(context.env);
  const result = await auth.refresh(validated['refreshToken'] as string);
  if (!result) throw new UnauthorizedError('Your session has expired. Please sign in again.');

  await new AuditRepository(context.env.DB).record({
    actorId: result.user.id,
    actorEmail: result.user.email,
    action: AUDIT_ACTIONS.TOKEN_REFRESHED,
    resourceType: 'user',
    resourceId: result.user.id,
    requestId: context.requestId,
  });

  return json(
    {
      accessToken: result.tokens.accessToken,
      refreshToken: result.tokens.refreshToken,
      expiresIn: result.tokens.expiresIn,
      user: serializeUser(result.user),
    },
    { headers: NO_STORE_HEADERS },
  );
}

export async function logout(context: RequestContext): Promise<Response> {
  const header = context.request.headers.get('authorization') ?? '';
  const token = header.toLowerCase().startsWith('bearer ') ? header.slice(7).trim() : '';

  const auth = new AuthService(context.env);
  const sessionId = token ? await auth.sessionIdFromToken(token) : null;
  if (sessionId) await auth.logout(sessionId);

  if (context.user) {
    await new AuditRepository(context.env.DB).record({
      actorId: context.user.id,
      actorEmail: context.user.email,
      action: AUDIT_ACTIONS.LOGOUT,
      resourceType: 'user',
      resourceId: context.user.id,
      requestId: context.requestId,
    });
  }

  return json({ message: 'You have been signed out.' }, { headers: NO_STORE_HEADERS });
}

/** `GET /api/auth/me` — who the caller is and what they may do. */
export async function me(context: RequestContext): Promise<Response> {
  if (!context.user) throw new UnauthorizedError('Please sign in to continue.');

  // Whether this account has completed its Okoli membership travels with the
  // identity rather than needing a request of its own. Contributing requires
  // it, so the question is asked on pages that have no other reason to know
  // anything about membership, and asking it here costs one indexed lookup on
  // a call the client already makes.
  const profile = await context.env.DB.prepare(
    'SELECT "handle", "membership_status", "membership_number" FROM "member_profiles" WHERE "user_id" = ? LIMIT 1',
  )
    .bind(context.user.id)
    .first<{ handle: string; membership_status: string; membership_number: string }>();

  return json(
    {
      ...serializeUser(context.user),
      isMember: profile?.membership_status === 'active',
      handle: profile?.handle ?? null,
      membershipNumber: profile?.membership_number ?? null,
      membershipStatus: profile?.membership_status ?? null,
    },
    { headers: NO_STORE_HEADERS },
  );
}

/**
 * `GET /api/auth/preservation-team`
 *
 * The structure of the volunteer organisation: positions, what each is
 * responsible for, and the platform roles each ordinarily receives. This is
 * organisational structure only — no member of the team is named here.
 */
export async function preservationTeamStructure(_context: RequestContext): Promise<Response> {
  return json({
    name: 'Ekoli-Yeden Preservation Team',
    positions: PRESERVATION_TEAM.map((position) => ({
      slug: position.slug,
      title: position.title,
      responsibility: position.responsibility,
      suggestedRoles: position.suggestedRoles,
      areas: position.areas,
    })),
  });
}

function serializeUser(user: {
  id: string;
  email: string;
  displayName: string;
  status: string;
  roles: string[];
  permissions: Set<string>;
}): Record<string, unknown> {
  return {
    id: user.id,
    email: user.email,
    displayName: user.displayName,
    status: user.status,
    roles: user.roles,
    permissions: [...user.permissions],
  };
}

/**
 * Whether a temporary password has outlived its window.
 *
 * Returns false when nothing was stamped, which covers accounts that were given
 * a temporary password before this check existed. Locking those people out
 * retroactively would punish them for a change they had no part in; they are
 * still forced to choose a real password on the way in.
 */
async function temporaryPasswordExpired(
  context: RequestContext,
  issuedAt: string | null,
): Promise<boolean> {
  if (!issuedAt) return false;

  const row = await context.env.DB
    .prepare('SELECT "value" FROM "site_settings" WHERE "key" = ? LIMIT 1')
    .bind('temp_password_ttl_hours')
    .first<{ value: string | null }>();

  const parsed = Number(row?.value ?? 72);
  const hours = Number.isFinite(parsed) && parsed > 0 ? parsed : 72;

  const issued = Date.parse(issuedAt);
  if (Number.isNaN(issued)) return false;

  return Date.now() - issued > hours * 3_600_000;
}
