import type { RequestContext } from '../types/api';
import { AuthService } from '../services/auth.service';
import { AuditRepository, AUDIT_ACTIONS } from '../repositories/audit.repository';
import { UnauthorizedError } from '../utils/errors';
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
    .string('password', { required: true, min: 12, max: 200, label: 'Password' })
    .string('display_name', { required: true, min: 2, max: 120, label: 'Name' })
    .validated();

  const auth = new AuthService(context.env);
  const userId = await auth.register({
    email: validated['email'] as string,
    password: validated['password'] as string,
    displayName: validated['display_name'] as string,
  });

  const audit = new AuditRepository(context.env.DB);
  await audit.record({
    actorId: userId,
    actorEmail: validated['email'] as string,
    action: AUDIT_ACTIONS.USER_CREATED,
    resourceType: 'user',
    resourceId: userId,
    changes: { via: 'self-registration', role: 'contributor' },
    requestId: context.requestId,
  });

  return json(
    {
      id: userId,
      message: 'Your account has been created. You may now sign in and contribute materials for review.',
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
  return json(serializeUser(context.user), { headers: NO_STORE_HEADERS });
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
